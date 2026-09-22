import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

import 'analysis_task_base.dart';

/// @nodoc
@internal
@injectable
// Analyzer bug: fails to associate the doc comment above with this
// primary-constructor class; the class is documented.
// ignore: public_member_api_docs
final class const AnalyzeTask({
  required super.programRunner,
  required super.fileResolver,
  required super.logger,
  @factoryParam required super.config,
}) extends AnalysisTaskBase {
  static const name = 'analyze';

  @override
  String get taskName => name;

  @override
  @protected
  @visibleForTesting
  Iterable<String> get analysisCommand => const ['analyze'];
}
