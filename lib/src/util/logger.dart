import 'dart:async';

enum TaskStatus {
  scanning,
  clean,
  hasChanges,
  hasUnstagedChanges,
  rejected,
}

enum LogLevel {
  debug,
  info,
  warn,
  error,
  except,
  nothing,
}

extension LogLevelX on LogLevel {
  String get name => toString().split('.').last;

  static LogLevel parse(String message) => LogLevel.values.firstWhere(
        (e) => e.name == message,
        orElse: () => throw ArgumentError.value(message, 'message'),
      );
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
  LogLevel get logLevel;
  set logLevel(LogLevel level);

  void updateStatus({
    String? message,
    TaskStatus? status,
    String? detail,
    bool clear = false,
  });

  void completeStatus();
}

extension LoggerX on Logger {
  bool canLog(LogLevel level) => level.index >= logLevel.index;
}
