import 'package:meta/meta.dart';

import 'repo_entry.dart';

/// The possible result states of a generic task.
///
/// Check [TaskResultX] for extended functionality.
enum TaskResult {
  /// The task completed with success, nothing had to be modified.
  accepted,

  /// The task completed with success, but had to modify one or more files that
  /// have to be added to the commit again.
  modified,

  /// The task completed, but detected a problem with the commit that must be
  /// solved before the commit can be accepted.
  rejected,
}

/// Methodical extensions for the [TaskResult] enum.
extension TaskResultX on TaskResult {
  /// Raises the hook result to a more severe level, if required.
  ///
  /// Compares this with [target] and returns the more severe result. The
  /// results severity is as according to the following table, the most severe
  /// result at the top:
  ///
  /// - [TaskResult.rejected]
  /// - [TaskResult.modified]
  /// - [TaskResult.accepted]
  ///
  /// So, if for example, you would call:
  /// ```.dart
  /// TaskResult.modified.raiseTo(TaskResult.rejected)
  /// ```
  /// if would return [TaskResult.rejected].
  TaskResult raiseTo(TaskResult target) => target.index > index ? target : this;
}

/// The base class for all tasks.
///
/// **Important:** Do *not* implement this class directly, instead user either
/// [FileTask] or [RepoTask], as one of these to is expected by [Hooks]. This
/// class only exists to perform common operations on all types of tasks.
abstract class TaskBase {
  /// Returns the user-visible name of the task.
  String get taskName;

  /// Checks if a [RepoEntry] can be processed by this task.
  ///
  /// The method is called with every staged or partially staged file. The paths
  /// are always relative to the current directory, not the repository root.
  bool canProcess(RepoEntry entry);
}

/// A task that is run multiple times, once for every matching file.
///
/// For this task, all staged files are filtered based on [filePattern] and then
/// each file is processed via [call()].
///
/// Use this kind of task in case your task does something atomically on a per
/// file basis, like formatting a file or checking file permissions. If the task
/// needs other files, like linting, which pulls in other files and thus is not
/// atomic, do not use this kind of task, use [RepoTask] instead.
///
/// Please note that tasks are executed on a per-file basis, meaning if there
/// are multiple tasks that can process a file, all are called on the file in
/// the same order they have been added to [Hooks]. Only then will the next file
/// be processed in the same manner. All [FileTask]s are always run before any
/// [RepoTask].
abstract class FileTask extends TaskBase {
  /// Executes the task on the given [entry].
  ///
  /// **Important:** This function should run without sideeffects, i.e. the
  /// following two examples should yield the exact same results, no matter
  /// what entries are passed to them:
  ///
  /// ```.dart
  /// // example 1
  /// final task = MyFileTask();
  /// await task(entry1);
  /// await task(entry2);
  /// await task(entry3);
  ///
  /// // example 2
  /// await MyFileTask()(entry1);
  /// await MyFileTask()(entry2);
  /// await MyFileTask()(entry2);
  /// ```
  ///
  /// This does not mean, you cannot cache data between multiple calls of a file
  /// task, but that should not modifiy the public behavior of subsequent calls.
  /// The only thing you must never cache is information about the given
  /// [entry] or any other local file in the repo, as those could be modified
  /// between different calls to you task by other tasks.
  Future<TaskResult> call(RepoEntry entry);
}

/// A task that runs once for the whole repository.
///
/// For this task, all staged files are filtered based on [filePattern] and the
/// list of filtered tasks is the passed to [call()]. If no files do match,
/// [callForEmptyEntries] defines the behaviour.
///
/// Use this kind of task in case your task does something that affects the
/// whole repository or uses multiple files at once, like checking for lints.
/// If you only do things on a per file basis, without sideeffects or
/// interaction between multiple files, you can use [FileTask] instead. The
/// [RepoTask] is also very useful if you want to perform certain operations at
/// the end of the hook, after all modifications.
///
/// Please note that tasks are executed in order, meaning if there are multiple
/// tasks that can process a file, all tasks are called in order, each with all
/// files that match the task. All [RepoTask]s are always run after any
/// [FileTask].
abstract class RepoTask extends TaskBase {
  /// Specifies, whether the task should still be executed, even if no files
  /// match.
  ///
  /// If true, the task always gets called. Otherwise it only gets called if at
  /// least one file matches [filePattern].
  bool get callForEmptyEntries;

  /// Executes the task on all given [entries].
  ///
  /// While [entries] contains only the staged files, you can used all files
  /// in the repository.
  ///
  /// Please note, that if you return [TaskResult.modified], all given [entries]
  /// will be added to git again, unless one is partially staged. If you do
  /// modify files that are not listed in [entries], you have to stage them
  /// yourself.
  Future<TaskResult> call(Iterable<RepoEntry> entries);
}

mixin PatternTaskMixin implements TaskBase {
  Pattern get filePattern;

  @override
  @nonVirtual
  bool canProcess(RepoEntry entry) =>
      filePattern.matchAsPrefix(entry.file.path) != null;
}
