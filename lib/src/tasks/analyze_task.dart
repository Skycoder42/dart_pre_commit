import 'package:freezed_annotation/freezed_annotation.dart';
import '../util/file_resolver.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';
import 'analysis_task_base.dart';
import 'provider/task_provider.dart';

// coverage:ignore-start
/// A riverpod provider for the analyze task.
final analyzeTaskProvider = TaskProvider.configurable(
  AnalyzeTask._taskName,
  AnalysisConfig.fromJson,
  (ref, config) => AnalyzeTask(
    fileResolver: ref.watch(fileResolverProvider),
    programRunner: ref.watch(programRunnerProvider),
    logger: ref.watch(taskLoggerProvider),
    config: config,
  ),
);
// coverage:ignore-end

/// @nodoc
@internal
final class AnalyzeTask extends AnalysisTaskBase {
  static const _taskName = 'analyze';

  const AnalyzeTask({
    required super.programRunner,
    required super.fileResolver,
    required super.logger,
    required super.config,
  });

  @override
  String get taskName => _taskName;

  @override
  @protected
  @visibleForTesting
  Iterable<String> get analysisCommand => const ['analyze'];
}
