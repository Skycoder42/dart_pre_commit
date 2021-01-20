import 'dart:async';

enum TaskStatus {
  scanning,
  clean,
  hasChanges,
  hasUnstagedChanges,
  rejected,
}

abstract class TaskLogger {
  void debug(String message);
  void info(String message);
  void warn(String message);
  void error(String message);

  void except(Exception exception, [StackTrace? stackTrace]);
  Future<void> pipeStderr(Stream<List<int>> stderr);
}

abstract class Logger implements TaskLogger {
  void updateStatus({
    String? message,
    TaskStatus? status,
    String? detail,
    bool clear = false,
  });

  void completeStatus();
}
