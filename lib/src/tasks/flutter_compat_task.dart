import 'dart:io';

import 'package:pubspec_parse/pubspec_parse.dart';

import '../../dart_pre_commit.dart';

typedef PubspecParseFactory = Pubspec Function(
  String yaml, {
  Uri? sourceUrl,
  bool lenient,
});

class FlutterCompatTask implements RepoTask {
  static final _pubspecRegexp = RegExp(r'^pubspec.ya?ml$');

  final ProgramRunner programRunner;

  final TaskLogger taskLogger;

  final PubspecParseFactory pubspecParseFactory;

  const FlutterCompatTask({
    required this.programRunner,
    required this.taskLogger,
    required this.pubspecParseFactory,
  });

  @override
  String get taskName => 'flutter-compat';

  @override
  bool get callForEmptyEntries => false;

  @override
  bool canProcess(RepoEntry entry) {
    if (!_pubspecRegexp.hasMatch(entry.file.path)) {
      return false;
    }

    // only run if not already a flutter project
    final pubspec = pubspecParseFactory(
      entry.file.readAsStringSync(),
      sourceUrl: entry.file.uri,
    );
    return !pubspec.dependencies.containsKey('flutter');
  }

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    for (final entry in entries) {
      final pubspec = pubspecParseFactory(
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
        );
        final exitCode = await programRunner.run(
          'flutter',
          [
            'pub',
            'add',
            pubspec.name,
            '--path',
            entry.file.parent.path,
          ],
          workingDirectory: tmpDir.path,
        );

        if (exitCode != 0) {
          taskLogger.error(
            'Failed add ${pubspec.name} to a flutter project '
            '(exit code: $exitCode)',
          );
          return TaskResult.rejected;
        }
      } finally {
        await tmpDir.delete(recursive: true);
      }
    }

    return TaskResult.accepted;
  }
}
