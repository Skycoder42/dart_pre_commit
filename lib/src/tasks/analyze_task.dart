import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'analysis_task_base.dart';

/// @nodoc
@internal
@injectable
final class AnalyzeTask extends AnalysisTaskBase {
  static const name = 'analyze';

  const AnalyzeTask({
    required super.programRunner,
    required super.fileResolver,
    required super.logger,
    @factoryParam required super.config,
  });

  @override
  String get taskName => name;

  @override
  @protected
  @visibleForTesting
  Iterable<String> get analysisCommand => const ['analyze'];
}
