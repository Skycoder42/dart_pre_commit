import 'dart:io';

import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:path/path.dart';
import 'package:riverpod/riverpod.dart';

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
    final excludeEntries = [
      Directory('.git'),
      Directory('.dart_tool'),
      Directory('coverage'),
      Directory('doc'),
      File('test/unit/tasks/fix_imports_task_test.dart'),
      File('test/unit/tasks/library_imports_task_test.dart'),
      File('test/integration/integration_test.dart'),
    ];

    await Directory.current
        .list(recursive: true, followLinks: false)
        .where((entry) => entry is File)
        .cast<File>()
        .where(
          (entry) => !excludeEntries.any(
            (exclude) =>
                isWithin(exclude.path, entry.path) ||
                equals(exclude.path, entry.path),
          ),
        )
        .map((entry) => RepoEntry(file: entry, partiallyStaged: false))
        .runFileTasks(di)
        .runRepoTasks(di);
  } catch (e, s) {
    di.read(HooksProviderInternal.loggerProvider).except(e as Exception, s);
  } finally {
    di.dispose();
  }
}

extension _TaskStreamX on Stream<RepoEntry> {
  Stream<RepoEntry> runFileTasks(ProviderContainer di) async* {
    final logger = di.read(HooksProviderInternal.loggerProvider);
    final tasks = [
      await di.read(HooksProviderInternal.fixImportsProvider.future),
      di.read(HooksProviderInternal.formatProvider),
    ];

    await for (final repoEntry in this) {
      logger.updateStatus(
        message: 'Scanning ${repoEntry.file.path}...',
        clear: true,
      );
      for (final task in tasks) {
        logger.updateStatus(detail: task.taskName);
        if (task.canProcess(repoEntry)) {
          final res = await task(repoEntry);
          if (res == TaskResult.rejected) {
            throw TaskRejectedException(task, repoEntry);
          }
        }
      }
      yield repoEntry;
    }
  }

  Future<void> runRepoTasks(ProviderContainer di) async {
    final logger = di.read(HooksProviderInternal.loggerProvider);
    final tasks = [
      di.read(HooksProviderInternal.analyzeProvider),
      di.read(HooksProviderInternal.outdatedProvider(OutdatedLevel.any)),
      di.read(HooksProviderInternal.nullsafeProvider),
      di.read(HooksProviderInternal.pullUpDependenciesProvider),
    ];

    final repoEntries = await toList();
    for (final task in tasks) {
      logger.updateStatus(
        message: 'Running ${task.taskName}...',
        clear: true,
      );
      final res = await task(repoEntries.where(task.canProcess));
      if (res == TaskResult.rejected) {
        throw TaskRejectedException(task);
      }
    }
  }
}
