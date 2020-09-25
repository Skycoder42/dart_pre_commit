import 'dart:io';

import 'package:dart_lint_hooks/src/analyze.dart';
import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import 'fix_imports.dart';
import 'format.dart';
import 'logger.dart';
import 'program_runner.dart';
import 'task_error.dart';

/// The result of a LintHooks call.
///
/// See [LintResultX] for extension methods defined on the enum.
enum LintResult {
  /// All is ok, nothing was modified.
  clean,

  /// Files had to be fixed up, but all succeeded and only fully staged files
  /// were affected.
  hasChanges,

  /// Files had to be fixed up, all succeeded but partially staged files had to
  /// be modified.
  hasUnstagedChanges,

  /// At least one staged file has analyze/lint errors and must be fixed.
  linter,

  /// An unexpected error occured.
  error,
}

/// Extension methods for [LintResult]
extension LintResultX on LintResult {
  /// Returns a boolean that indicates whether the result should be treated as
  /// success or as failure.
  ///
  /// The following table lists how result codes are interpreted:
  ///
  /// Code                            | Success
  /// --------------------------------|---------
  /// [LintResult.clean]              | true
  /// [LintResult.hasChanges]         | true
  /// [LintResult.hasUnstagedChanges] | false
  /// [LintResult.linter]             | false
  /// [LintResult.error]              | false
  bool get isSuccess => index <= LintResult.hasChanges.index;

  LintResult _raiseTo(LintResult target) =>
      target.index > index ? target : this;
}

/// A callable class the runs the hooks on a repository
///
/// This is the main entrypoint of the library. The class will scan your
/// repository for staged files and run all activated hooks on them, reporting
/// a result. Check the documentation of [FixImports], [Format] and [Analyze]
/// for more details on the actual supported hook operations.
class LintHooks {
  /// The [Logger] instance used to log progress and errors
  final Logger logger;

  /// The [ProgramRunner] used to invoke git
  final ProgramRunner runner;

  /// An optional instance of [FixImports] to run as hook on staged files
  final FixImports fixImports;

  /// An optional instance of [Format] to run as hook on staged files
  final Format format;

  /// An optional instance of [Analyze] to run as hook on staged files
  final Analyze analyze;

  /// Specifies, whether processing should continue on errors.
  ///
  /// Normally, once one of the hook operations fails for one file, the whole
  /// process is aborted with an error. If however [continueOnError] is set to
  /// true, instead processing of that file will be skipped and all other files
  /// are still processed. In both cases, [call()] will resolve with
  /// [LintResult.error].
  final bool continueOnError;

  /// Constructs a new [LintHooks] instance.
  ///
  /// The [logger] and [runner] parameters are required and need to be valid
  /// instances of the respective classes.
  ///
  /// The [fixImports], [format] and [analyze] are optional. If specified, they
  /// will be called as part of the hook, if null they are left out. This allows
  /// you to control, which hooks to actually run.
  ///
  /// The [continueOnError] can be used to control error behaviour. See
  /// [this.continueOnError] for details.
  const LintHooks({
    @required this.logger,
    @required this.runner,
    this.fixImports,
    this.format,
    this.analyze,
    this.continueOnError = false,
  });

  static Future<LintHooks> atomic({
    bool fixImports = true,
    bool format = true,
    bool analyze = true,
    bool continueOnError = false,
    Logger logger = const Logger.standard(),
  }) async {
    final runner = ProgramRunner(logger);
    return LintHooks(
      logger: logger,
      runner: runner,
      fixImports: fixImports ? await _obtainFixImports() : null,
      format: format ? Format(runner) : null,
      analyze: analyze ? Analyze(logger: logger, runner: runner) : null,
      continueOnError: continueOnError,
    );
  }

  Future<LintResult> call() async {
    try {
      var lintState = LintResult.clean;
      final files = await _collectFiles();

      for (final entry in files.entries) {
        final file = File(entry.key);
        try {
          logger.log("Scanning ${file.path}...");
          var modified = false;
          if (fixImports != null) {
            modified = await fixImports(file) || modified;
          }
          if (format != null) {
            modified = await format(file) || modified;
          }

          if (modified) {
            if (entry.value) {
              logger.log("(!) Fixing up partially staged file ${file.path}");
              lintState = lintState._raiseTo(LintResult.hasUnstagedChanges);
            } else {
              logger.log("Fixing up ${file.path}");
              lintState = lintState._raiseTo(LintResult.hasChanges);
              await _git(["add", file.path]).drain<void>();
            }
          }
        } on TaskError catch (error) {
          logger.logError(error);
          if (!continueOnError) {
            return LintResult.error;
          } else {
            lintState = lintState._raiseTo(LintResult.error);
          }
        }
      }

      if (analyze != null) {
        if (await analyze(files.keys)) {
          lintState = lintState._raiseTo(LintResult.linter);
        }
      }

      return lintState;
    } on TaskError catch (error) {
      logger.logError(error);
      return LintResult.error;
    }
  }

  Future<Map<String, bool>> _collectFiles() async {
    final indexChanges = await _git(["diff", "--name-only"]).toList();
    final stagedChanges = _git(["diff", "--name-only", "--cached"]);
    return {
      await for (var path in stagedChanges)
        if (path.endsWith(".dart")) path: indexChanges.contains(path),
    };
  }

  Stream<String> _git([List<String> arguments = const []]) =>
      runner.stream("git", arguments);

  static Future<FixImports> _obtainFixImports() async {
    final pubspecFile = File("pubspec.yaml");
    final yamlData = loadYamlDocument(
      await pubspecFile.readAsString(),
      sourceUrl: pubspecFile.uri,
    ).contents as YamlMap;

    return FixImports(
      libDir: Directory("lib"),
      packageName: yamlData.value["name"] as String,
    );
  }
}
