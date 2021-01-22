import '../repo_entry.dart';
import '../task_base.dart';
import '../util/program_runner.dart';

class FormatTask implements FileTask {
  final ProgramRunner programRunner;

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
