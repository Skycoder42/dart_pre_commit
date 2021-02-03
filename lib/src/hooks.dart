import 'dart:io';

import 'package:path/path.dart';

import 'repo_entry.dart';
import 'task_base.dart';
import 'util/file_resolver.dart';
import 'util/logger.dart';
import 'util/program_runner.dart';

/// The result of a [Hooks] call.
///
/// See [HookResultX] for extension methods defined on the enum.
enum HookResult {
  /// All is ok, nothing was modified.
  clean,

  /// Files had to be fixed up, but all succeeded and only fully staged files
  /// were affected.
  hasChanges,

  /// Files had to be fixed up, all succeeded but partially staged files had to
  /// be modified.
  hasUnstagedChanges,

  /// At least one hook detected a problem that has to be fixed manually before
  /// the commit can be accepted
  rejected,
}

/// Extension methods for [HookResult]
extension HookResultX on HookResult {
  /// Returns a boolean that indicates whether the result should be treated as
  /// success or as failure.
  ///
  /// The following table lists how result codes are interpreted:
  ///
  /// Code                            | Success
  /// --------------------------------|---------
  /// [HookResult.clean]              | true
  /// [HookResult.hasChanges]         | true
  /// [HookResult.hasUnstagedChanges] | false
  /// [HookResult.rejected]           | false
  bool get isSuccess => index <= HookResult.hasChanges.index;

  HookResult _raiseTo(HookResult target) =>
      target.index > index ? target : this;

  TaskStatus _toStatus() {
    switch (this) {
      case HookResult.clean:
        return TaskStatus.clean;
      case HookResult.hasChanges:
        return TaskStatus.hasChanges;
      case HookResult.hasUnstagedChanges:
        return TaskStatus.hasUnstagedChanges;
      case HookResult.rejected:
        return TaskStatus.rejected;
    }
  }
}

extension _HookResultStreamX on Stream<HookResult> {
  Future<HookResult> raise([HookResult base = HookResult.clean]) =>
      fold(base, (previous, element) => previous._raiseTo(element));
}

class _RejectedException implements Exception {
  const _RejectedException();
}

/// A callable class the runs the hooks on a repository.
///
/// This is the main entrypoint of the library. The class will scan your
/// repository for staged files and run all activated hooks on them, reporting
/// a result. Check the documentation of [FixImportsTask], [FormatTask],
/// [AnalyzeTask] and [PullUpDependenciesTask] for more details on the actual
/// supported hook operations. Check the Tasks category for a list of all tasks.
///
/// For an easier use of this class and the standard hook tasks, see
/// [HooksProvider].
class Hooks {
  final FileResolver _fileResolver;
  final ProgramRunner _programRunner;
  final List<TaskBase> _tasks;

  /// The [Logger] instance used to log progress and errors
  final Logger logger;

  /// Specifies, whether processing should continue on rejections.
  ///
  /// Normally, once one of the hook operations detects an unfixable problem,
  /// the whole process is aborted with [HookResult.rejected]. If however
  /// [continueOnRejected] is set to true, instead processing will continue as
  /// usual. In both cases, [call()] will resolve with [HookResult.rejected].
  final bool continueOnRejected;

  /// Returns all tasks this hook will run on the repository upon [call()].
  Iterable<String> get tasks => _tasks.map((t) => t.taskName);

  /// Constructs a new [Hooks] instance.
  ///
  /// The [logger], [fileResolver] and [programRunner] are needed by this class,
  /// see their documentation for details.
  ///
  /// The [tasks] parameter can be used to provide a list of all tasks that
  /// should be run upon [call()]. Each task can either be a [FileTask] or as
  /// [RepoTask]. Check the Tasks category for a list of all tasks.
  ///
  /// The [continueOnRejected] can be used to control rejection behaviour. See
  /// [this.continueOnRejected] for details.
  const Hooks({
    required this.logger,
    required FileResolver fileResolver,
    required ProgramRunner programRunner,
    required List<TaskBase> tasks,
    this.continueOnRejected = false,
  })  : _fileResolver = fileResolver,
        _programRunner = programRunner,
        _tasks = tasks;

  /// Executes all enabled hooks on the current repository.
  ///
  /// The command will run expecting [Directory.current] to be the git
  /// repository, or a subdirectory within it, to be processed. It collects all
  /// staged files and then runs all enabled hooks on these files.
  ///
  /// The result is determined based on the collective result of all processed
  /// files and hooks. A [HookResult.clean] result is only possible if all
  /// operations are clean. If at least one staged file had to modified, the
  /// result is [HookResult.hasChanges]. If at least one file was partially
  /// staged, it will be [HookResult.hasUnstagedChanges] instead. The
  /// [HookResult.rejected] will be the result if any task finds at least one
  /// file with problems that cannot be fixed automatically.
  Future<HookResult> call() async {
    try {
      final entries = await _collectStagedFiles().toList();

      var lintState = HookResult.clean;
      lintState = await Stream.fromIterable(entries)
          .asyncMap(_scanEntry)
          .raise(lintState);
      lintState = await Stream.fromIterable(_tasks.whereType<RepoTask>())
          .asyncMap((task) => _evaluateRepoTask(task, entries))
          .raise(lintState);

      return lintState;
    } on _RejectedException {
      return HookResult.rejected;
    }
  }

  Future<HookResult> _scanEntry(RepoEntry entry) async {
    try {
      logger.updateStatus(
        message: 'Scanning ${entry.file.path}...',
        status: TaskStatus.scanning,
        refresh: false,
      );
      var scanResult = TaskResult.accepted;
      for (final task in _tasks.whereType<FileTask>()) {
        if (task.canProcess(entry)) {
          final taskResult = await _runFileTask(task, entry);
          scanResult = scanResult.raiseTo(taskResult);
        }
      }
      final hookResult = await _processTaskResult(scanResult, entry);
      _logFileTaskResult(hookResult, entry);
      return hookResult;
    } on _RejectedException {
      _logFileTaskResult(HookResult.rejected, entry);
      rethrow;
    } finally {
      logger.completeStatus();
    }
  }

  Future<TaskResult> _runFileTask(FileTask task, RepoEntry entry) async {
    logger.updateStatus(detail: '[${task.taskName}]');
    final taskResult = await task(entry);
    _checkTaskRejected(taskResult);
    return taskResult;
  }

  void _logFileTaskResult(HookResult hookResult, RepoEntry entry) {
    String message;
    switch (hookResult) {
      case HookResult.clean:
        message = 'Accepted file ${entry.file.path}';
        break;
      case HookResult.hasChanges:
        message = 'Fixed up ${entry.file.path}';
        break;
      case HookResult.hasUnstagedChanges:
        message = 'Fixed up partially staged file ${entry.file.path}';
        break;
      case HookResult.rejected:
        message = 'Rejected file ${entry.file.path}';
        break;
    }
    logger.updateStatus(
      status: hookResult._toStatus(),
      message: message,
      clear: true,
    );
  }

  Future<HookResult> _evaluateRepoTask(
    RepoTask task,
    List<RepoEntry> entries,
  ) async {
    final filteredEntries = entries.where(task.canProcess).toList();
    if (filteredEntries.isNotEmpty || task.callForEmptyEntries) {
      return _runRepoTask(task, filteredEntries);
    } else {
      return HookResult.clean;
    }
  }

  Future<HookResult> _runRepoTask(
    RepoTask task,
    List<RepoEntry> entries,
  ) async {
    try {
      logger.updateStatus(
        message: 'Running ${task.taskName}...',
        status: TaskStatus.scanning,
      );
      final taskResult = await task(entries);
      _checkTaskRejected(taskResult);
      final hookResult = await _processMultiTaskResult(taskResult, entries);
      _logRepoTaskResult(hookResult, task);
      return hookResult;
    } on _RejectedException {
      _logRepoTaskResult(HookResult.rejected, task);
      rethrow;
    } finally {
      logger.completeStatus();
    }
  }

  void _logRepoTaskResult(HookResult hookResult, RepoTask task) {
    String message;
    switch (hookResult) {
      case HookResult.clean:
        message = 'Completed ${task.taskName}';
        break;
      case HookResult.hasChanges:
        message = 'Completed ${task.taskName}, fixed up some files';
        break;
      case HookResult.hasUnstagedChanges:
        message =
            'Completed ${task.taskName}, fixed up some partially staged files';
        break;
      case HookResult.rejected:
        message = 'Completed ${task.taskName}, found problems';
        break;
    }
    logger.updateStatus(
      status: hookResult._toStatus(),
      message: message,
      clear: true,
    );
  }

  void _checkTaskRejected(TaskResult result) {
    if (!continueOnRejected && result == TaskResult.rejected) {
      throw const _RejectedException();
    }
  }

  Future<HookResult> _processTaskResult(
    TaskResult taskResult,
    RepoEntry? entry,
  ) async {
    switch (taskResult) {
      case TaskResult.accepted:
        return HookResult.clean;
      case TaskResult.modified:
        if (entry?.partiallyStaged ?? false) {
          return HookResult.hasUnstagedChanges;
        } else {
          if (entry != null) {
            await _programRunner.stream('git', [
              'add',
              entry.file.path,
            ]).drain<void>();
          }
          return HookResult.hasChanges;
        }
      case TaskResult.rejected:
        assert(continueOnRejected);
        return HookResult.rejected;
    }
  }

  Future<HookResult> _processMultiTaskResult(
    TaskResult taskResult,
    List<RepoEntry> entries,
  ) async {
    if (entries.isEmpty) {
      return _processTaskResult(taskResult, null);
    } else {
      return Stream.fromIterable(entries)
          .asyncMap((entry) => _processTaskResult(taskResult, entry))
          .raise();
    }
  }

  Stream<RepoEntry> _collectStagedFiles() async* {
    final gitRoot = await _gitRoot();
    final indexChanges = await _streamGitFiles(gitRoot, [
      'diff',
      '--name-only',
    ]).toList();
    final stagedChanges = _streamGitFiles(gitRoot, [
      'diff',
      '--name-only',
      '--cached',
    ]);

    await for (final path in stagedChanges) {
      final file = _fileResolver.file(path);
      if (!await file.exists()) {
        continue;
      }
      yield RepoEntry(
        file: file,
        partiallyStaged: indexChanges.contains(path),
      );
    }
  }

  Future<String> _gitRoot() async => Directory(
        await _programRunner.stream('git', const [
          'rev-parse',
          '--show-toplevel',
        ]).first,
      ).resolveSymbolicLinks();

  Stream<String> _streamGitFiles(
    String gitRoot,
    List<String> arguments,
  ) async* {
    final resolvedCurrent = await Directory.current.resolveSymbolicLinks();
    yield* _programRunner
        .stream('git', arguments)
        .map((path) => join(gitRoot, path))
        .where((path) => isWithin(resolvedCurrent, path))
        .map((path) => relative(path, from: resolvedCurrent));
  }
}
