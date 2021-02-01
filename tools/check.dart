import 'dart:io';

import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:path/path.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

class TaskRejectedException implements Exception {
  final TaskBase task;
  final RepoEntry? entry;

  const TaskRejectedException(this.task, [this.entry]);

  @override
  String toString() => entry != null
      ? 'Task ${task.taskName} rejected ${entry!.file.path}'
      : 'Task ${task.taskName} rejected the repository';
}

Future<void> main() async {
  final di = ProviderContainer();
  try {
    await _runFileTasks(di);
  } catch (e, s) {
    di.read(HooksProviderInternal.loggerProvider).except(e as Exception, s);
  } finally {
    di.dispose();
  }
}

Future<void> _runFileTasks(ProviderContainer di) async {
  final logger = di.read(HooksProviderInternal.loggerProvider);
  final tasks = [
    await di.read(HooksProviderInternal.fixImportsProvider.future),
    di.read(HooksProviderInternal.formatProvider),
  ];

  final excludeDirs = [
    Directory('.git'),
    Directory('.dart_tool'),
    Directory('coverage'),
    Directory('doc'),
  ];
  await for (final entry in Directory.current.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entry is! File) {
      continue;
    }
    if (excludeDirs.any((dir) => isWithin(dir.path, entry.path))) {
      continue;
    }

    final repoEntry = RepoEntry(file: entry, partiallyStaged: false);
    logger.updateStatus(
      message: 'Scanning ${entry.path}...',
      clear: true,
    );
    for (final task in tasks) {
      logger.updateStatus(detail: task.taskName);
      if (task.canProcess(repoEntry)) {
        final res = await task(repoEntry);
        if (res == TaskResult.rejected) {}
      }
    }
  }
}
