import 'package:freezed_annotation/freezed_annotation.dart';

import '../util/file_resolver.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';
import 'analysis_task_base.dart';
import 'provider/task_provider.dart';

// coverage:ignore-start
/// A riverpod provider for the custom-lint task.
final customLintTaskProvider = TaskProvider.configurable(
  CustomLintTask._taskName,
  AnalysisConfig.fromJson,
  (ref, config) => CustomLintTask(
    programRunner: ref.watch(programRunnerProvider),
    fileResolver: ref.watch(fileResolverProvider),
    logger: ref.watch(taskLoggerProvider),
    config: config,
  ),
);

// coverage:ignore-end

/// @nodoc
@internal
final class CustomLintTask extends AnalysisTaskBase {
  static const _taskName = 'custom-lint';

  const CustomLintTask({
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
  Iterable<String> get analysisCommand => const ['run', 'custom_lint'];
}
