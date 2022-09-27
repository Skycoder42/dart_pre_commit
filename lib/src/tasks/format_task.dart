import 'package:riverpod/riverpod.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/program_runner.dart';

final formatTaskProvider = Provider(
  (ref) => FormatTask(
    programRunner: ref.watch(programRunnerProvider),
  ),
);

/// A task the runs `dart format` on the given file.
///
/// This task simply runs dart to format the staged file before committing it.
/// The formatted file is immediately saved and staged again, if something had
/// to be fixed. In that case, [TaskResult.modified] is returned.
///
/// {@category tasks}
class FormatTask with PatternTaskMixin implements FileTask {
  /// The [ProgramRunner] instance used by this task.
  final ProgramRunner programRunner;

  /// Default Constructor.
  const FormatTask({
    required this.programRunner,
  });

  @override
  String get taskName => 'format';

  @override
  Pattern get filePattern => RegExp(r'^.*\.dart$');

  @override
  Future<TaskResult> call(RepoEntry entry) async {
    const program = 'dart';
    final arguments = [
      'format',
      '--fix',
      '--set-exit-if-changed',
      entry.file.path,
    ];
    final exitCode = await programRunner.run(program, arguments);
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
