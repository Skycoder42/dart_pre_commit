import 'dart:io';

import 'package:pubspec_parse/pubspec_parse.dart';

import '../../dart_pre_commit.dart';
import 'provider/task_provider.dart';

final flutterCompatTaskProvider = TaskProvider(
  FlutterCompatTask._taskName,
  (ref) => FlutterCompatTask(
    programRunner: ref.watch(programRunnerProvider),
    taskLogger: ref.watch(taskLoggerProvider),
  ),
);

/// A task that checks if the package can be added to a flutter project.
///
/// Flutter hardcodes certain package versions in their SDK, making any package
/// that requires a different version of that package incompatible to all
/// flutter projects. This task tries to create a temporary flutter project and
/// add this package to it as dependency to check if such problems exist.
///
/// {@category tasks}
class FlutterCompatTask implements RepoTask {
  static const _taskName = 'flutter-compat';
  static final _pubspecRegexp = RegExp(r'^pubspec.ya?ml$');

  /// The [ProgramRunner] instance used by this task.
  final ProgramRunner programRunner;

  /// The [TaskLogger] instance used by this task.
  final TaskLogger taskLogger;

  /// Default Constructor.
  const FlutterCompatTask({
    required this.programRunner,
    required this.taskLogger,
  });

  @override
  String get taskName => _taskName;

  @override
  bool get callForEmptyEntries => false;

  @override
  bool canProcess(RepoEntry entry) {
    if (!_pubspecRegexp.hasMatch(entry.file.path)) {
      return false;
    }

    // only run if not already a flutter project
    final pubspec = Pubspec.parse(
      entry.file.readAsStringSync(),
      sourceUrl: entry.file.uri,
    );
    return !pubspec.dependencies.containsKey('flutter');
  }

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    for (final entry in entries) {
      final pubspec = Pubspec.parse(
        await entry.file.readAsString(),
        sourceUrl: entry.file.uri,
      );

      final tmpDir = await Directory.systemTemp.createTemp();
      try {
        await programRunner.run(
          'flutter',
          const ['create', '--project-name', 't', '.'],
          workingDirectory: tmpDir.path,
          failOnExit: true,
          runInShell: Platform.isWindows,
        );
        final exitCode = await programRunner.run(
          'flutter',
          [
            'pub',
            'add',
            pubspec.name,
            '--path',
            entry.file.parent.absolute.path,
          ],
          workingDirectory: tmpDir.path,
          runInShell: Platform.isWindows,
        );

        if (exitCode != 0) {
          taskLogger.error(
            'Failed add ${pubspec.name} to a flutter project '
            '(exit code: $exitCode)',
          );
          return TaskResult.rejected;
        }

        taskLogger.info('Package ${pubspec.name} is flutter compatible');
      } finally {
        await tmpDir.delete(recursive: true);
      }
    }

    return TaskResult.accepted;
  }
}
