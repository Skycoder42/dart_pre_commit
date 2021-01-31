import 'dart:async';

/// The status a [TaskBase] can be in.
enum TaskStatus {
  /// The task is currently running.
  scanning,

  /// The task completed with [TaskResult.accepted].
  clean,

  /// The task completed with [TaskResult.modified], only fully staged files.
  hasChanges,

  /// The task completed with [TaskResult.modified] and partially staged files.
  hasUnstagedChanges,

  /// The task completed with [TaskResult.rejected].
  rejected,
}

/// The logging level that different log messages can have.
///
/// See [LogLevelX] for extensions on the enum.
enum LogLevel {
  /// Print all messages.
  debug,

  /// Print informational messages.
  info,

  /// Print warnings and errors only.
  warn,

  /// Print errors only.
  error,

  /// Print exceptions only.
  except,

  /// Print nothing at all.
  nothing,
}

/// Extensions on [LogLevel], that add additional logic to the enum.
extension LogLevelX on LogLevel {
  /// The short name of the value, without the enum class name.
  String get name => toString().split('.').last;

  /// Static method to create a [LogLevel] from the [message].
  ///
  /// The [message] must a a valid log level, see [name].
  static LogLevel parse(String message) => LogLevel.values.firstWhere(
        (e) => e.name == message,
        orElse: () => throw ArgumentError.value(message, 'message'),
      );
}

/// The interface for the logger as [TaskBase] classes expect it.
///
/// This can be used to log messages in a task context, without the extended
/// status logic. This class is typically not implemented directly, instead
/// implement [Logger] and implement the methods there.
abstract class TaskLogger {
  /// Logs a message with [LogLevel.debug].
  void debug(String message);

  /// Logs a message with [LogLevel.info].
  void info(String message);

  /// Logs a message with [LogLevel.warn].
  void warn(String message);

  /// Logs a message with [LogLevel.error].
  void error(String message);

  /// Logs an exception with [LogLevel.except].
  void except(Exception exception, [StackTrace? stackTrace]);

  /// Pipes the stderr of for example a process to the logger
  Future<void> pipeStderr(Stream<List<int>> stderr);
}

/// The primary logger interface, with status functionality.
///
/// Extends the [TaskLogger] and provides the status methods that are used by
/// [Hooks] in addition to the normal log methods.
abstract class Logger implements TaskLogger {
  /// The current [LogLevel] level of the logger.
  ///
  /// Based on this level, different log messages may or may not be visible. The
  /// rule here is: All levels that are equal or higher then the given
  /// [logLevel] are displayed, all that are lower are silently discarded.
  ///
  /// The log levels severity is the same as the [LogLevel.index]. You can use
  /// the [LoggerX.canLog()] method to check if the current logger should log
  /// a specific log level
  LogLevel get logLevel;
  set logLevel(LogLevel level);

  /// Updates the current status message.
  ///
  /// This method is used by [Hooks] to keep the user informed about what is
  /// currently happening, that is, which files and tasks are currently beeing
  /// processed. It also serves as a headline/barrier between "normal" log
  /// messages, so they can be easily grouped and mapped to a certain task/file.
  ///
  /// The current status message is replaced with a new one. If there is no
  /// status message yet, it is created.
  ///
  /// The [message] parameter provides the primary message that should be
  /// displayed to the user. [status] is converted to a symbol, emoji, letter or
  /// similar, that is shown before the message to indicate in which status the
  /// current task is. With [detail], you can add a small suffix message to the
  /// status, that gives the user a more detailed hint on what is happening.
  /// Unless [clear] is specified, old values are kept and only replaced by
  /// explicit parameters. If set to true, the old status will be completely
  /// cleared before applying new values.
  void updateStatus({
    String? message,
    TaskStatus? status,
    String? detail,
    bool clear = false,
  });

  /// Completes the current status message.
  ///
  /// The next time you call [updateStatus], it will be a new message. The old
  /// one is kept in the log history with it's last state.
  void completeStatus();
}

/// Extensions to the [Logger] class.
extension LoggerX on Logger {
  /// Checks if a message with [level] should be logged by this logger.
  bool canLog(LogLevel level) => level.index >= logLevel.index;
}
