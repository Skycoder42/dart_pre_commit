import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:dart_pre_commit/src/repo_entry.dart';

class TaskException implements Exception {
  final String message;
  final String? task;
  final RepoEntry? entry;

  TaskException(this.message)
      : task = TaskExceptionScope._current?.task.taskName,
        entry = TaskExceptionScope._current?.entry;

  @override
  String toString() {
    final infoMsg = task != null ? '[$task] $message' : message;
    return entry != null ? '${entry!.file.path}: $infoMsg' : infoMsg;
  }
}

class TaskExceptionScope {
  static final List<TaskExceptionScope> _stack = [];

  static TaskExceptionScope? get _current =>
      _stack.isNotEmpty ? _stack.last : null;

  final TaskBase task;
  final RepoEntry? entry;

  TaskExceptionScope(this.task, [this.entry]) {
    _stack.add(this);
  }

  void dispose() {
    assert(_stack.last == this);
    _stack.removeAt(_stack.length - 1);
  }
}
