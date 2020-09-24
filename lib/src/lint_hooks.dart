import 'dart:io';

import 'package:dart_lint_hooks/src/analyze.dart';
import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import 'fix_imports.dart';
import 'format.dart';
import 'logger.dart';
import 'program_runner.dart';
import 'task_error.dart';

enum LintResult {
  clean,
  hasChanges,
  hasUnstagedChanges,
  linter,
  error,
}

extension _LintResultX on LintResult {
  LintResult raiseTo(LintResult target) => target.index > index ? target : this;
}

class LintHooks {
  final Logger logger;
  final ProgramRunner runner;
  final FixImports fixImports;
  final Format format;
  final Analyze analyze;
  final bool continueOnError;

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
              lintState = lintState.raiseTo(LintResult.hasUnstagedChanges);
            } else {
              logger.log("Fixing up ${file.path}");
              lintState = lintState.raiseTo(LintResult.hasChanges);
              await _git(["add", file.path]).drain<void>();
            }
          }
        } on TaskError catch (error) {
          logger.logError(error);
          if (!continueOnError) {
            return LintResult.error;
          } else {
            lintState = lintState.raiseTo(LintResult.error);
          }
        }
      }

      if (analyze != null) {
        if (await analyze(files.keys)) {
          lintState = lintState.raiseTo(LintResult.linter);
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
