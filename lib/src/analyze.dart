import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart';

import 'logger.dart';
import 'program_runner.dart';
import 'task_error.dart';

class AnalyzeResult {
  String severity;
  String category;
  String type;
  String path;
  int line;
  int column;
  int length;
  String description;

  @override
  String toString() {
    return "  ${category.toLowerCase()} - $description - $path:$line:$column - ${type.toLowerCase()}";
  }
}

class Analyze {
  final Logger logger;
  final ProgramRunner runner;

  const Analyze({
    @required this.logger,
    @required this.runner,
  });

  Future<bool> call(Iterable<String> files) async {
    final lints = {
      for (final file in files) _toPosixPath(file): <AnalyzeResult>[],
    };
    logger.log("Running linter...");
    await for (final entry in _runAnalyze()) {
      if (lints.containsKey(entry.path)) {
        lints[entry.path].add(entry);
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

  static String _toPosixPath(String path) =>
      posix.joinAll(split(relative(path)));

  Stream<AnalyzeResult> _runAnalyze() async* {
    final allDirs = await Stream.fromIterable([
      Directory("lib"),
      Directory("bin"),
      Directory("test"),
    ])
        .asyncMap((d) async => [await d.exists(), d.path])
        .where((e) => e[0] as bool)
        .map((e) => e[1] as String)
        .toList();

    yield* runner
        .stream(
          Platform.isWindows ? "dartanalyzer.bat" : "dartanalyzer",
          [
            "--format",
            "machine",
            ...allDirs,
          ],
          failOnExit: false,
          useStderr: true,
        )
        .parseResult();
  }
}

extension ResultTransformer on Stream<String> {
  Stream<AnalyzeResult> parseResult() async* {
    await for (final line in this) {
      final elements = line.trim().split("|");
      if (elements.length < 8) {
        throw TaskError("Invalid output from dartanalyzer: $line");
      }
      yield AnalyzeResult()
        ..severity = elements[0]
        ..category = elements[1]
        ..type = elements[2]
        ..path = Analyze._toPosixPath(elements[3])
        ..line = int.parse(elements[4], radix: 10)
        ..column = int.parse(elements[5], radix: 10)
        ..length = int.parse(elements[6], radix: 10)
        ..description = elements.sublist(7).join("|");
    }
  }
}
