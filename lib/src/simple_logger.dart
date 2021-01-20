import 'dart:io';

import 'package:dart_pre_commit/src/logger.dart';

class SimpleLogger implements Logger {
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
    if (_statusState != null) {
      stdout.write('${_statusState!.icon} ');
    }
    stdout.write(_statusMessage);
    if (_statusDetail != null) {
      stdout.write(' $_statusDetail');
    }
    stdout.writeln();
  }

  @override
  void completeStatus() {}

  @override
  void debug(String message) => stdout.writeln('  [DBG] $message');

  @override
  void info(String message) => stdout.writeln('  [INF] $message');

  @override
  void warn(String message) => stdout.writeln('  [WRN] $message');

  @override
  void error(String message) => stdout.writeln('  [ERR] $message');

  @override
  void except(Exception exception, [StackTrace? stackTrace]) =>
      stackTrace != null
          ? stdout.writeln('  [EXC] $exception\n$stackTrace')
          : stdout.writeln('  [EXC] $exception');

  @override
  Future<void> pipeStderr(Stream<List<int>> errStream) =>
      errStream.listen(stderr.add).asFuture();
}

extension TaskStatusIconX on TaskStatus {
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
        return '[E]';
    }
  }
}
