import 'dart:async';
import 'dart:convert';

import 'package:console/console.dart'; // ignore: import_of_legacy_library_into_null_safe
import 'package:dart_pre_commit/src/logger.dart';

class ConsoleLogger implements Logger {
  String _statusMessage = '';
  TaskStatus? _statusState;
  String? _statusDetail;

  @override
  void updateStatus({
    String? message,
    TaskStatus? status,
    String? detail,
    bool clear = false,
  }) {
    _statusMessage = message ?? (clear ? '' : _statusMessage);
    _statusState = status ?? (clear ? null : _statusState);
    _statusDetail = detail ?? (clear ? null : _statusDetail);
    Console.eraseLine();
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
  void completeStatus() => Console.nextLine();

  @override
  void debug(String message) => _log(message, Color.LIGHT_GRAY);

  @override
  void info(String message) => _log(message, Color.BLUE);

  @override
  void warn(String message) => _log(message, Color.GOLD);

  @override
  void error(String message) => _log(message, Color.RED);

  @override
  void except(Exception exception, [StackTrace? stackTrace]) => _log(
        stackTrace != null ? '$exception\n$stackTrace' : exception.toString(),
        Color.MAGENTA,
      );

  @override
  Future<void> pipeStderr(Stream<List<int>> stderr) => stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((event) => _log(event, Color.DARK_RED))
      .asFuture();

  void _log(String message, [Color? color]) {
    try {
      Console.eraseLine();
      if (color != null) {
        Console.setTextColor(color.id);
      }
      Console.write('  ');
      Console.write(message);
    } finally {
      if (color != null) {
        Console.resetTextColor();
      }
      Console.nextLine();
      updateStatus();
    }
  }
}

extension TaskStatusIconX on TaskStatus {
  String get icon {
    switch (this) {
      case TaskStatus.scanning:
        return '🔎';
      case TaskStatus.clean:
        return '✔';
      case TaskStatus.hasChanges:
        return '🖉';
      case TaskStatus.hasUnstagedChanges:
        return '⚠';
      case TaskStatus.rejected:
        return '❌';
    }
  }
}
