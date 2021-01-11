import 'repo_entry.dart';

abstract class TaskBase {
  String get taskName;
  Pattern get filePattern;
}

abstract class FileTask extends TaskBase {
  Future<bool> call(RepoEntry entry);
}

abstract class RepoTask extends TaskBase {
  bool get callForEmptyEntries;

  Future<bool> call(Iterable<RepoEntry> entries);
}
