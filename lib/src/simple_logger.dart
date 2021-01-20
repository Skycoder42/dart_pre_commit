import 'dart:io';

import 'package:dart_pre_commit/src/logger.dart';

class SimpleLogger implements Logger {
  final IOSink outSink;
  final IOSink errSink;

  String _statusMessage = '';
  TaskStatus? _statusState;
  String? _statusDetail;

  SimpleLogger({
    IOSink? outSink,
    IOSink? errSink,
  })  : outSink = outSink ?? stdout,
        errSink = errSink ?? stderr;

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
  void debug(String message) => outSink.writeln('  [DBG] $message');

  @override
  void info(String message) => outSink.writeln('  [INF] $message');

  @override
  void warn(String message) => outSink.writeln('  [WRN] $message');

  @override
  void error(String message) => outSink.writeln('  [ERR] $message');

  @override
  void except(Exception exception, [StackTrace? stackTrace]) =>
      stackTrace != null
          ? outSink.writeln('  [EXC] $exception\n$stackTrace')
          : outSink.writeln('  [EXC] $exception');

  @override
  Future<void> pipeStderr(Stream<List<int>> errStream) =>
      errStream.listen(errSink.add).asFuture();
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
        return '[R]';
    }
  }
}
