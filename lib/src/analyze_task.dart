import 'package:dart_pre_commit/src/logger.dart';
import 'package:path/path.dart';

import 'file_resolver.dart';
import 'program_runner.dart';
import 'repo_entry.dart';
import 'task_base.dart';

class AnalyzeResult {
  final String category;
  final String type;
  final String path;
  final int line;
  final int column;
  final String description;

  AnalyzeResult({
    required this.category,
    required this.type,
    required this.path,
    required this.line,
    required this.column,
    required this.description,
  });

  @override
  String toString() =>
      '  $category - $description at $path:$line:$column - ($type)';
}

class AnalyzeTask implements RepoTask {
  final ProgramRunner programRunner;
  final FileResolver fileResolver;
  final TaskLogger logger;

  const AnalyzeTask({
    required this.programRunner,
    required this.fileResolver,
    required this.logger,
  });

  @override
  String get taskName => 'analyze';

  @override
  Pattern get filePattern => RegExp(r'^(?:pubspec.ya?ml|.*\.dart)$');

  @override
  bool get callForEmptyEntries => false;

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    final lints = {
      for (final entry in entries) entry.file.path: <AnalyzeResult>[],
    };
    assert(lints.isNotEmpty);

    await for (final entry in _runAnalyze()) {
      final lintList = lints.entries
          .cast<MapEntry<String, List<AnalyzeResult>>?>()
          .firstWhere(
            (lint) => equals(entry.path, lint!.key),
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
          logger.info(lint.toString());
        }
      }
    }

    logger.info('$lintCnt issue(s) found.');
    return lintCnt > 0 ? TaskResult.rejected : TaskResult.accepted;
  }

  Stream<AnalyzeResult> _runAnalyze() async* {
    yield* programRunner
        .stream(
          'dart',
          const [
            'analyze',
            '--fatal-infos',
          ],
          failOnExit: false,
        )
        .parseResult(
          fileResolver: fileResolver,
          logger: logger,
        );
  }
}

extension _ResultTransformer on Stream<String> {
  Stream<AnalyzeResult> parseResult({
    required FileResolver fileResolver,
    required TaskLogger logger,
  }) async* {
    final regExp = RegExp(
      r'^\s*(\w+)\s+-\s+([^-]+)\s+at\s+([^-:]+?):(\d+):(\d+)\s+-\s+\((\w+)\)\s*$',
    );
    await for (final line in this) {
      final match = regExp.firstMatch(line);
      if (match != null) {
        final res = AnalyzeResult(
          category: match[1]!,
          type: match[6]!,
          path: await fileResolver.resolve(match[3]!),
          line: int.parse(match[4]!, radix: 10),
          column: int.parse(match[5]!, radix: 10),
          description: match[2]!,
        );
        yield res;
      } else {
        logger.debug('Skipping analyze line: $line');
      }
    }
  }
}
