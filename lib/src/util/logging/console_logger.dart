import 'dart:async';
import 'dart:convert';

import 'package:console/console.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

import '../logger.dart';
import 'logging_module.dart';

@internal
const ansiEnv = Environment('ansi');

@internal
@Singleton(as: Logger)
@ansiEnv
class ConsoleLogger implements Logger {
  var _statusMessage = '';
  TaskStatus? _statusState;
  String? _statusDetail;
  var _freshStatus = false;

  @override
  final LogLevel logLevel;

  /// Default constructor.
  ///
  /// The [logLevel], which is [LogLevel.info] by default, can be adjusted to
  /// control how much is logged.
  new(LogLevelFactory logLevelFactory) : logLevel = logLevelFactory();

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
    _freshStatus = true;

    Console.overwriteLine('');
    if (_statusState != null) {
      Console.write('${_statusState!.icon} ');
    }
    Console.write(_statusMessage);
    if (_statusDetail != null) {
      try {
        Console.setItalic(true);
        Console.write(' $_statusDetail');
      } finally {
        Console.setItalic(false);
      }
    }
  }

  @override
  void completeStatus() {
    Console.write('\n');
  }

  @override
  void debug(String message) => _log(LogLevel.debug, message, Color.GREEN);

  @override
  void info(String message) => _log(LogLevel.info, message, Color.DARK_BLUE);

  @override
  void warn(String message) => _log(LogLevel.warn, message, Color.GOLD);

  @override
  void error(String message) => _log(LogLevel.error, message, Color.DARK_RED);

  @override
  void except(Exception exception, [StackTrace? stackTrace]) => _log(
    LogLevel.except,
    stackTrace != null ? '$exception\n$stackTrace' : exception.toString(),
    Color.MAGENTA,
  );

  @override
  Future<void> pipeStderr(Stream<List<int>> stderr) => stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((event) => _log(LogLevel.error, event, Color.DARK_RED))
      .asFuture();

  void _log(LogLevel level, String message, [Color? color]) {
    if (!canLog(level)) {
      return;
    }

    try {
      if (_freshStatus) {
        Console.write('\n');
      } else {
        Console.overwriteLine('');
      }
      if (color != null) {
        Console.setTextColor(color.id);
      }
      Console.write('    ');
      Console.write(message);
    } finally {
      if (color != null) {
        Console.resetTextColor();
      }
      Console.write('\n');
      updateStatus();
      _freshStatus = false;
    }
  }
}

extension _TaskStatusIconX on TaskStatus {
  String get icon {
    switch (this) {
      case TaskStatus.scanning:
        return '🔎';
      case TaskStatus.clean:
        return '✅';
      case TaskStatus.hasChanges:
        return '✏️';
      case TaskStatus.hasUnstagedChanges:
        return '⚠️';
      case TaskStatus.rejected:
        return '❌';
    }
  }
}
