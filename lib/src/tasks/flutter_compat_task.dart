import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';

/// @nodoc
@internal
@injectable
class FlutterCompatTask implements RepoTask {
  static const name = 'flutter-compat';
  static final _pubspecRegexp = RegExp(r'^pubspec.ya?ml$');

  final ProgramRunner _programRunner;

  final TaskLogger _taskLogger;

  /// @nodoc
  const FlutterCompatTask(this._programRunner, this._taskLogger);

  @override
  String get taskName => name;

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
        await _programRunner.run(
          'flutter',
          const ['create', '--project-name', 't', '.'],
          workingDirectory: tmpDir.path,
          failOnExit: true,
          runInShell: Platform.isWindows,
        );
        final exitCode = await _programRunner.run(
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
          _taskLogger.error(
            'Failed add ${pubspec.name} to a flutter project '
            '(exit code: $exitCode)',
          );
          return TaskResult.rejected;
        }

        _taskLogger.info('Package ${pubspec.name} is flutter compatible');
      } finally {
        await tmpDir.delete(recursive: true);
      }
    }

    return TaskResult.accepted;
  }
}
