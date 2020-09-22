import 'dart:io';

abstract class Logger {
  // ignore: unused_element
  const Logger._();

  const factory Logger.standard() = _DefaultLogger;

  void log(dynamic data);
  void logError(dynamic error);
  void pipeStderr(Stream<List<int>> errStream);
}

class _DefaultLogger implements Logger {
  const _DefaultLogger();

  @override
  void log(dynamic data) {
    stdout.writeln(data);
  }

  @override
  void logError(dynamic error) {
    stderr.writeln(error);
  }

  @override
  void pipeStderr(Stream<List<int>> errStream) {
    errStream.pipe(stderr);
  }
}
