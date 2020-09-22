import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

import 'logger.dart';

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
    return "${category.toLowerCase()} - $description - $path:$line:$column - $type";
  }
}

class Analyze {
  final List<String> files;
  final Logger logger;

  const Analyze({
    this.files,
    this.logger,
  });

  Future<bool> call() async {
    final lints = {
      for (final file in files) file: const <AnalyzeResult>[],
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
          logger.log(lint);
        }
      }
    }

    logger.log("$lintCnt lint(s) found.");
    return lintCnt > 0;
  }

  Stream<AnalyzeResult> _runAnalyze() async* {
    final process = await Process.start(
      Platform.isWindows ? "dartanalyzer.bat" : "dartanalyzer",
      [
        "--format",
        "machine",
        ...files,
      ],
    );
    logger.pipeStderr(process.stderr);
    yield* process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .parseResult();
  }
}

extension ResultTransformer on Stream<String> {
  Stream<AnalyzeResult> parseResult() async* {
    await for (final line in this) {
      final elements = line.trim().split("|");
      if (elements.length < 8) {
        throw "Invalid output from dartanalyzer: $line";
      }
      yield AnalyzeResult()
        ..severity = elements[0]
        ..category = elements[1]
        ..type = elements[2]
        ..path = relative(elements[3])
        ..line = int.parse(elements[4], radix: 10)
        ..column = int.parse(elements[5], radix: 10)
        ..length = int.parse(elements[6], radix: 10)
        ..description = elements.sublist(7).join("|");
    }
  }
}
