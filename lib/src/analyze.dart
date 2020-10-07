import 'dart:io';

import 'package:dart_pre_commit/src/file_resolver.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';

import 'logger.dart';
import 'program_runner.dart';

class AnalyzeResult {
  String category;
  String type;
  String path;
  int line;
  int column;
  String description;

  @override
  String toString() {
    return "  $category - $description at $path:$line:$column - ($type)";
  }
}

class Analyze {
  final Logger logger;
  final ProgramRunner runner;
  final FileResolver fileResolver;

  const Analyze({
    @required this.logger,
    @required this.runner,
    @required this.fileResolver,
  });

  Future<bool> call(Iterable<String> files) async {
    final lints = {
      await for (final file in fileResolver.resolveAll(files))
        file: <AnalyzeResult>[],
    };
    logger.log("Running dart analyze...");
    await for (final entry in _runAnalyze()) {
      final lintList = lints.entries
          .firstWhere(
            (lint) => equals(entry.path, lint.key),
            orElse: () => null,
          )
          ?.value;
      if (lintList != null) {
        lintList.add(entry);
      }
    }

    var lintCnt = 0;
    for (final entry in lints.entries) {
      if (entry.value.isNotEmpty) {
        for (final lint in entry.value) {
          ++lintCnt;
          logger.log(lint.toString());
        }
      }
    }

    logger.log("$lintCnt issue(s) found.");
    return lintCnt > 0;
  }

  Stream<AnalyzeResult> _runAnalyze() async* {
    yield* runner
        .stream(
          "dart",
          const [
            "analyze",
            "--fatal-infos",
          ],
          failOnExit: false,
        )
        .parseResult(fileResolver);
  }
}

extension ResultTransformer on Stream<String> {
  Stream<AnalyzeResult> parseResult(FileResolver fileResolver) async* {
    final regExp = RegExp(
        r"^\s*(\w+)\s+-\s+([^-]+)\s+at\s+([^-:]+?):(\d+):(\d+)\s+-\s+\((\w+)\)\s*$");
    await for (final line in this) {
      final match = regExp.firstMatch(line);
      if (match != null) {
        final res = AnalyzeResult()
          ..category = match[1]
          ..type = match[6]
          ..path = await fileResolver.resolve(match[3])
          ..line = int.parse(match[4], radix: 10)
          ..column = int.parse(match[5], radix: 10)
          ..description = match[2];
        yield res;
      }
    }
  }
}
