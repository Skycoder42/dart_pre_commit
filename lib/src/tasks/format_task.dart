import 'package:freezed_annotation/freezed_annotation.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/program_runner.dart';
import 'provider/task_provider.dart';

part 'format_task.freezed.dart';
part 'format_task.g.dart';

// coverage:ignore-start
/// A riverpod provider for the format task.
final formatTaskProvider = TaskProvider.configurable(
  FormatTask._taskName,
  FormatConfig.fromJson,
  (ref, config) => FormatTask(
    programRunner: ref.watch(programRunnerProvider),
    config: config,
  ),
);
// coverage:ignore-end

/// @nodoc
@freezed
@internal
sealed class FormatConfig with _$FormatConfig {
  /// @nodoc
  // ignore: invalid_annotation_target
  @JsonSerializable(anyMap: true, checked: true, disallowUnrecognizedKeys: true)
  const factory FormatConfig({
    // ignore: invalid_annotation_target
    @JsonKey(name: 'line-length') int? lineLength,
  }) = _FormatConfig;

  /// @nodoc
  factory FormatConfig.fromJson(Map<String, dynamic> json) =>
      _$FormatConfigFromJson(json);
}

/// @nodoc
@internal
class FormatTask with PatternTaskMixin implements FileTask {
  static const _taskName = 'format';

  final ProgramRunner _programRunner;

  final FormatConfig _config;

  /// @nodoc
  const FormatTask({
    required ProgramRunner programRunner,
    required FormatConfig config,
  }) : _programRunner = programRunner,
       _config = config;

  @override
  String get taskName => _taskName;

  @override
  Pattern get filePattern => RegExp(r'^.*\.dart$');

  @override
  Future<TaskResult> call(RepoEntry entry) async {
    const program = 'dart';
    final arguments = [
      'format',
      '--set-exit-if-changed',
      if (_config.lineLength != null) ...[
        '--line-length',
        _config.lineLength!.toString(),
      ],
      entry.file.path,
    ];
    final exitCode = await _programRunner.run(program, arguments);
    switch (exitCode) {
      case 0:
        return TaskResult.accepted;
      case 1:
        return TaskResult.modified;
      default:
        throw ProgramExitException(exitCode, program, arguments);
    }
  }
}
