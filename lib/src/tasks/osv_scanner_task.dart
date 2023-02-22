import 'package:meta/meta.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/program_runner.dart';
import 'provider/task_provider.dart';

// coverage:ignore-start
/// A riverpod provider for the osv scanner task.
final osvScannerTaskProvider = TaskProvider(
  OsvScannerTask._taskName,
  (ref) => OsvScannerTask(
    programRunner: ref.watch(programRunnerProvider),
  ),
);
// coverage:ignore-end

/// @nodoc
@internal
class OsvScannerTask with PatternTaskMixin implements RepoTask {
  static const _taskName = 'osv-scanner';
  static const osvScannerBinary = 'osv-scanner';

  final ProgramRunner _programRunner;

  /// @nodoc
  const OsvScannerTask({
    required ProgramRunner programRunner,
  }) : _programRunner = programRunner;

  @override
  String get taskName => _taskName;

  @override
  Pattern get filePattern => RegExp(r'^pubspec\.(?:ya?ml|lock)$');

  @override
  bool get callForEmptyEntries => false;

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    final result = await _programRunner.run(
      osvScannerBinary,
      const ['--lockfile', 'pubspec.lock'],
      forwardStdOut: true,
    );

    return result == 0 ? TaskResult.accepted : TaskResult.rejected;
  }
}
