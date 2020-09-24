import 'dart:io';

import 'package:dart_lint_hooks/src/analyze.dart';
import 'package:get_it/get_it.dart';
import 'package:yaml/yaml.dart';

import 'fix_imports.dart';
import 'format.dart';
import 'logger.dart';
import 'program_runner.dart';
import 'task_error.dart';

enum LintResult {
  clean,
  linter,
  hasChanges,
  hasUnstagedChanges,
  error,
}

class LintHooks {
  final bool fixImports;
  final bool format;
  final bool analyze;
  final bool continueOnError;

  final Logger _logger;
  final ProgramRunner _runner;
  final Format _runFormat;

  LintHooks({
    this.fixImports = true,
    this.format = true,
    this.analyze = true,
    this.continueOnError = false,
    Logger logger,
    ProgramRunner runner,
    Format runFormat,
  })  : _logger = logger ?? GetIt.I.get<Logger>(),
        _runner = runner ?? GetIt.I.get<ProgramRunner>(),
        _runFormat = runFormat ?? GetIt.I.get<Format>();

  Future<LintResult> call() async {
    try {
      final runFixImports = await _obtainFixImports();

      var lintState = LintResult.clean;

      final files = await _collectFiles();
      for (final entry in files.entries) {
        final file = File(entry.key);
        try {
          _logger.log("Scanning ${file.path}...");
          var modified = false;
          if (fixImports) {
            modified = await runFixImports(file) || modified;
          }
          if (format) {
            modified = await _runFormat(file) || modified;
          }

          if (modified) {
            if (entry.value) {
              _logger.log("(!) Fixing up partially staged file ${file.path}");
              lintState =
                  _updateResult(lintState, LintResult.hasUnstagedChanges);
            } else {
              _logger.log("Fixing up ${file.path}");
              lintState = _updateResult(lintState, LintResult.hasChanges);
              await _git(["add", file.path]).drain<void>();
            }
          }
        } on TaskError catch (error) {
          _logger.logError(error);
          if (!continueOnError) {
            return LintResult.error;
          } else {
            lintState = _updateResult(lintState, LintResult.error);
          }
        }
      }

      if (analyze) {
        final analyzer = Analyze(
          files: files.keys.toList(),
          logger: _logger,
          runner: _runner,
        );

        if (await analyzer()) {
          lintState = _updateResult(lintState, LintResult.linter);
        }
      }

      return lintState;
    } on TaskError catch (error) {
      _logger.logError(error);
      return LintResult.error;
    }
  }

  Future<Map<String, bool>> _collectFiles() async {
    final indexChanges = await _git(["diff", "--name-only"]).toList();
    final stagedChanges = _git(["diff", "--name-only", "--cached"]);
    return {
      await for (var path in stagedChanges)
        if (path.isNotEmpty && path.endsWith(".dart"))
          path: indexChanges.contains(path),
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

  static LintResult _updateResult(LintResult current, LintResult updated) =>
      updated.index > current.index ? updated : current;
}
