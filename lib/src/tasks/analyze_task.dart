import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/file_resolver.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';
import 'provider/task_provider.dart';

part 'analyze_task.freezed.dart';
part 'analyze_task.g.dart';

final analyzeTaskProvider = TaskProvider.configurable(
  AnalyzeTask._taskName,
  AnalyzeConfig.fromJson,
  (ref, config) => AnalyzeTask(
    fileResolver: ref.watch(fileResolverProvider),
    programRunner: ref.watch(programRunnerProvider),
    logger: ref.watch(taskLoggerProvider),
    config: config,
  ),
);

class _AnalyzeResult {
  final String category;
  final String type;
  final String path;
  final int line;
  final int column;
  final String description;

  _AnalyzeResult({
    required this.category,
    required this.type,
    required this.path,
    required this.line,
    required this.column,
    required this.description,
  });

  @override
  String toString() => [
        '  $category',
        '$path:$line:$column',
        description,
        type,
      ].join(' - ');
}

enum AnalyzeErrorLevel {
  error(['--no-fatal-warnings']),
  warning(['--fatal-warnings']),
  info(['--fatal-warnings', '--fatal-infos']);

  final List<String> _params;

  const AnalyzeErrorLevel(this._params);
}

@freezed
class AnalyzeConfig with _$AnalyzeConfig {
  // ignore: invalid_annotation_target
  @JsonSerializable(
    anyMap: true,
    checked: true,
    disallowUnrecognizedKeys: true,
  )
  const factory AnalyzeConfig({
    @Default(AnalyzeErrorLevel.info) AnalyzeErrorLevel errorLevel,
  }) = _AnalyzeConfig;

  factory AnalyzeConfig.fromJson(Map<String, dynamic> json) =>
      _$AnalyzeConfigFromJson(json);
}

/// A task the runs `dart analyze` to check for problems.
///
/// This task analyzes all files in the repository for problems and then filters
/// the results for all files that have been staged in this commit. If anything
/// was found for the staged files, the task will print out the problems and
/// exit with [TaskResult.rejected].
///
/// {@category tasks}
class AnalyzeTask with PatternTaskMixin implements RepoTask {
  static const _taskName = 'analyze';

  /// The [ProgramRunner] instance used by this task.
  final ProgramRunner programRunner;

  /// The [FileResolver] instance used by this task.
  final FileResolver fileResolver;

  /// The [TaskLogger] instance used by this task.
  final TaskLogger logger;

  final AnalyzeConfig config;

  /// Default Constructor.
  const AnalyzeTask({
    required this.programRunner,
    required this.fileResolver,
    required this.logger,
    required this.config,
  });

  @override
  String get taskName => _taskName;

  @override
  Pattern get filePattern => RegExp(r'^(?:pubspec.ya?ml|.*\.dart)$');

  @override
  bool get callForEmptyEntries => false;

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    if (entries.isEmpty) {
      throw ArgumentError('must not be empty', 'entries');
    }
    final lints = {
      for (final entry in entries) entry.file.path: <_AnalyzeResult>[],
    };

    await for (final entry in _runAnalyze()) {
      final lintList = lints.entries
          .cast<MapEntry<String, List<_AnalyzeResult>>?>()
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

  Stream<_AnalyzeResult> _runAnalyze() async* {
    yield* programRunner
        .stream(
          'dart',
          [
            'analyze',
            ...config.errorLevel._params,
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
  Stream<_AnalyzeResult> parseResult({
    required FileResolver fileResolver,
    required TaskLogger logger,
  }) async* {
    final regExp = RegExp(
      r'^\s*(\w+)\s+-\s+([^:]+?):(\d+):(\d+)\s+-\s+(.+?)\s+-\s+(\w+)\s*$',
    );
    await for (final line in this) {
      final match = regExp.firstMatch(line);
      if (match != null) {
        final res = _AnalyzeResult(
          category: match[1]!,
          type: match[6]!,
          path: await fileResolver.resolve(match[2]!),
          line: int.parse(match[3]!, radix: 10),
          column: int.parse(match[4]!, radix: 10),
          description: match[5]!,
        );
        yield res;
      } else {
        logger.debug('Skipping analyze line: $line');
      }
    }
  }
}
