import 'program_runner.dart';
import 'repo_entry.dart';
import 'task_base.dart';
import 'task_exception.dart';

class FormatTask implements FileTask {
  final ProgramRunner runner;

  const FormatTask(this.runner);

  @override
  String get taskName => 'format';

  @override
  Pattern get filePattern => RegExp(r'^.*\.dart$');

  @override
  Future<TaskResult> call(RepoEntry entry) async {
    final exitCode = await runner.run(
      'dart',
      [
        'format',
        '--fix',
        '--set-exit-if-changed',
        entry.file.path,
      ],
    );
    switch (exitCode) {
      case 0:
        return TaskResult.accepted;
      case 1:
        return TaskResult.modified;
      default:
        throw TaskException('dartfmt failed to format the file');
    }
  }
}
