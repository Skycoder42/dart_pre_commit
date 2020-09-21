import 'dart:io';

import 'package:yaml/yaml.dart';

import 'fix_imports.dart';
import 'format.dart';
import 'run_program.dart';

class LintHooks {
  final bool fixImports;
  final bool format;
  final bool analyze;

  LintHooks({
    this.fixImports = true,
    this.format = true,
    this.analyze = true,
  });

  Future<bool> call() async {
    try {
      const runFormat = Format();
      final runFixImports = await _obtainFixImports();

      final files = await _collectFiles();
      var hasPartiallyModified = false;
      for (final entry in files.entries) {
        final file = File(entry.key);
        if (!file.path.endsWith(".dart")) {
          continue;
        }

        stdout.writeln("Fixing up ${file.path}");
        var modified = false;
        if (fixImports) {
          modified = await runFixImports(file) || modified;
        }
        if (format) {
          modified = await runFormat(file) || modified;
        }

        if (modified) {
          if (entry.value) {
            hasPartiallyModified = true;
            stdout.writeln("\tWARNING: modified partially staged file");
          } else {
            await _git(["add", file.path]).drain<void>();
          }
        }
      }

      if (analyze) {}

      return !hasPartiallyModified;
    } catch (e) {
      stderr.writeln(e.toString());
      return false;
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
      runProgram("git", arguments);

  Future<FixImports> _obtainFixImports() async {
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
