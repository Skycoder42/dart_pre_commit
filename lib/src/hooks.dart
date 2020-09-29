import 'dart:io';

import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import 'analyze.dart';
import 'fix_imports.dart';
import 'format.dart';
import 'logger.dart';
import 'program_runner.dart';
import 'task_error.dart';

/// The result of a LintHooks call.
///
/// See [HookResultX] for extension methods defined on the enum.
enum HookResult {
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

/// Extension methods for [HookResult]
extension HookResultX on HookResult {
  /// Returns a boolean that indicates whether the result should be treated as
  /// success or as failure.
  ///
  /// The following table lists how result codes are interpreted:
  ///
  /// Code                            | Success
  /// --------------------------------|---------
  /// [HookResult.clean]              | true
  /// [HookResult.hasChanges]         | true
  /// [HookResult.hasUnstagedChanges] | false
  /// [HookResult.linter]             | false
  /// [HookResult.error]              | false
  bool get isSuccess => index <= HookResult.hasChanges.index;

  HookResult _raiseTo(HookResult target) =>
      target.index > index ? target : this;
}

/// A callable class the runs the hooks on a repository
///
/// This is the main entrypoint of the library. The class will scan your
/// repository for staged files and run all activated hooks on them, reporting
/// a result. Check the documentation of [FixImports], [Format] and [Analyze]
/// for more details on the actual supported hook operations.
class Hooks {
  final ProgramRunner _runner;
  final FixImports _fixImports;
  final Format _format;
  final Analyze _analyze;

  /// The [Logger] instance used to log progress and errors
  final Logger logger;

  /// Specifies, whether processing should continue on errors.
  ///
  /// Normally, once one of the hook operations fails for one file, the whole
  /// process is aborted with an error. If however [continueOnError] is set to
  /// true, instead processing of that file will be skipped and all other files
  /// are still processed. In both cases, [call()] will resolve with
  /// [HookResult.error].
  final bool continueOnError;

  @visibleForTesting
  const Hooks.internal({
    @required this.logger,
    @required ProgramRunner runner,
    FixImports fixImports,
    Format format,
    Analyze analyze,
    this.continueOnError = false,
  })  : _runner = runner,
        _fixImports = fixImports,
        _format = format,
        _analyze = analyze;

  /// Constructs a new [Hooks] instance.
  ///
  /// You can use [fixImports], [format] and [analyze] to specify which hooks to
  /// run. By default, all three of them are enabled.
  ///
  /// If [fixImports] is enabled, all staged files will be scanned for import
  /// order and imports will be sorted, first by category (sdk, package,
  /// relative) and then alphabetically. In addition, package imports of the
  /// current package within lib will be converted to relative imports.
  ///
  /// If [format] is true, then all staged files will be formatted with
  /// `dartfmt`, enabeling all possible fixes.
  ///
  /// If [analyze] is set, as final step, the `dartanalyzer` tool will be run
  /// and collect lints for all staged files. If at least one staged file has
  /// problems, the problems will be printed out and the command will fail.
  /// Lints are not fixed automatically. Instead, you have to fix them yourself
  /// or ignore them.
  ///
  /// The [logger] writes data to [stdout]/[stderr] by default, but a custom
  /// logger can be specified to customize how data is logged. See [Logger]
  /// documentation for more details.
  ///
  /// The [continueOnError] can be used to control error behaviour. See
  /// [this.continueOnError] for details.
  static Future<Hooks> create({
    bool fixImports = true,
    bool format = true,
    bool analyze = true,
    bool continueOnError = false,
    Logger logger = const Logger.standard(),
  }) async {
    final runner = ProgramRunner(logger);
    return Hooks.internal(
      logger: logger,
      runner: runner,
      fixImports: fixImports ? await _obtainFixImports() : null,
      format: format ? Format(runner) : null,
      analyze: analyze ? Analyze(logger: logger, runner: runner) : null,
      continueOnError: continueOnError,
    );
  }

  /// Executes all enabled hooks on the current repository.
  ///
  /// The command will run expecting [Directory.current] to be the git
  /// repository to be processed. It collects all staged files and then runs all
  /// enabled hooks on these files. See [Hooks.create()] for more details on
  /// what hooks are available and how to configure this instance.
  ///
  /// The result is determined based on the collective result of all processed
  /// files and hooks. A [HookResult.clean] result is only possible if all
  /// operations are clean. If at least one staged file had to modified, the
  /// result is [HookResult.hasChanges]. If at least one file was partially
  /// staged, it will be [HookResult.hasUnstagedChanges] instead. The
  /// [HookResult.linter] will be the result if the analyzer finds at least one
  /// file with problems, regardless of error-level or whether files have
  /// already been modified by other hooks. [HookResult.error] trumps all other
  /// results, as at least one error means that the operation has failed.
  Future<HookResult> call() async {
    try {
      var lintState = HookResult.clean;
      final files = await _collectFiles();

      for (final entry in files.entries) {
        final file = File(entry.key);
        try {
          logger.log("Scanning ${file.path}...");
          var modified = false;
          if (_fixImports != null) {
            modified = await _fixImports(file) || modified;
          }
          if (_format != null) {
            modified = await _format(file) || modified;
          }

          if (modified) {
            if (entry.value) {
              logger.log("(!) Fixing up partially staged file ${file.path}");
              lintState = lintState._raiseTo(HookResult.hasUnstagedChanges);
            } else {
              logger.log("Fixing up ${file.path}");
              lintState = lintState._raiseTo(HookResult.hasChanges);
              await _git(["add", file.path]).drain<void>();
            }
          }
        } on TaskError catch (error) {
          logger.logError(error);
          if (!continueOnError) {
            return HookResult.error;
          } else {
            lintState = lintState._raiseTo(HookResult.error);
          }
        }
      }

      if (_analyze != null) {
        if (await _analyze(files.keys)) {
          lintState = lintState._raiseTo(HookResult.linter);
        }
      }

      return lintState;
    } on TaskError catch (error) {
      logger.logError(error);
      return HookResult.error;
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
      _runner.stream("git", arguments);

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
