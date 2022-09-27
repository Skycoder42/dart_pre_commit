import 'dart:io';

import 'package:riverpod/riverpod.dart';

import '../logger.dart';
import 'console_logger.dart';

final simpleLoggerProvider = Provider<Logger>(
  (ref) => SimpleLogger(),
);

/// A simple logger class, the provides file-optimized logs.
///
/// These logs are plain, color- and decoration-less, without any special
/// symbols or control characters. You typically use this logger, if the logging
/// target is a plain file or some other, linear data stream that is not meant
/// to be displayed by a rich terminal.
///
/// For advanced logging, i.e. to a console/TTY, use [ConsoleLogger] instead.
class SimpleLogger implements Logger {
  /// The [IOSink] for normal log messages
  final IOSink outSink;

  /// The [IOSink] for forwarding error output from subprocesses.
  ///
  /// See [pipeStderr()] for more details.
  final IOSink errSink;

  @override
  LogLevel logLevel;

  String _statusMessage = '';
  TaskStatus? _statusState;
  String? _statusDetail;

  /// Default constructor.
  ///
  /// If not specified, [outSink] and [errSink] will be set to [stdout] and
  /// [stderr] repectively. The [logLevel], which is [LogLevel.info] by default,
  /// can be adjusted to control how much is logged.
  SimpleLogger({
    IOSink? outSink,
    IOSink? errSink,
    this.logLevel = LogLevel.info,
  })  : outSink = outSink ?? stdout,
        errSink = errSink ?? stderr;

  @override
  void updateStatus({
    String? message,
    TaskStatus? status,
    String? detail,
    bool clear = false,
    bool refresh = true,
  }) {
    _statusMessage = message ?? (clear ? '' : _statusMessage);
    _statusState = status ?? (clear ? null : _statusState);
    _statusDetail = detail ?? (clear ? null : _statusDetail);
    if (!refresh) {
      return;
    }

    if (_statusState != null) {
      outSink.write('${_statusState!.icon} ');
    }
    outSink.write(_statusMessage);
    if (_statusDetail != null) {
      outSink.write(' $_statusDetail');
    }
    outSink.writeln();
  }

  @override
  void completeStatus() {}

  @override
  void debug(String message) {
    if (canLog(LogLevel.debug)) {
      outSink.writeln('  [DBG] $message');
    }
  }

  @override
  void info(String message) {
    if (canLog(LogLevel.info)) {
      outSink.writeln('  [INF] $message');
    }
  }

  @override
  void warn(String message) {
    if (canLog(LogLevel.warn)) {
      outSink.writeln('  [WRN] $message');
    }
  }

  @override
  void error(String message) {
    if (canLog(LogLevel.error)) {
      outSink.writeln('  [ERR] $message');
    }
  }

  @override
  void except(Exception exception, [StackTrace? stackTrace]) {
    if (canLog(LogLevel.except)) {
      final stackLog = stackTrace != null ? '\n$stackTrace' : '';
      outSink.writeln('  [EXC] $exception$stackLog');
    }
  }

  @override
  Future<void> pipeStderr(Stream<List<int>> errStream) => errStream.listen((e) {
        if (canLog(LogLevel.error)) {
          errSink.add(e);
        }
      }).asFuture();
}

extension _TaskStatusIconX on TaskStatus {
  String get icon {
    switch (this) {
      case TaskStatus.scanning:
        return '[S]';
      case TaskStatus.clean:
        return '[C]';
      case TaskStatus.hasChanges:
        return '[M]';
      case TaskStatus.hasUnstagedChanges:
        return '[U]';
      case TaskStatus.rejected:
        return '[R]';
    }
  }
}
