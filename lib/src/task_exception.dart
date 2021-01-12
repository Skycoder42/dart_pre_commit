import 'package:dart_pre_commit/src/repo_entry.dart';

class TaskException implements Exception {
  final String message;
  final RepoEntry? entry;

  const TaskException(this.message, [this.entry]);

  @override
  String toString() =>
      entry != null ? '${entry?.file.path ?? 'unknown'}: $message' : message;
}
