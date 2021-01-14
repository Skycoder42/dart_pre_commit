import 'repo_entry.dart';

enum TaskResult {
  accepted,
  modified,
  rejected,
}

extension TaskResultX on TaskResult {
  TaskResult raiseTo(TaskResult target) => target.index > index ? target : this;
}

abstract class TaskBase {
  String get taskName;
  Pattern get filePattern;
}

abstract class FileTask extends TaskBase {
  Future<TaskResult> call(RepoEntry entry);
}

abstract class RepoTask extends TaskBase {
  bool get callForEmptyEntries;

  Future<TaskResult> call(Iterable<RepoEntry> entries);
}

extension TaskBaseX on TaskBase {
  bool canProcess(RepoEntry entry) =>
      filePattern.matchAsPrefix(entry.file.path) != null;
}
