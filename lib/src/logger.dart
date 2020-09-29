import 'dart:io';

/// Basic interface to provide logging functionality to the hooks
///
/// You can implement this interface to customize logging. The default
/// implementation, obtained via [Logger.standard()], will simply forward all
/// output to [stdout] and [stderr]
abstract class Logger {
  // ignore: unused_element
  const Logger._();

  /// Returns an instance of the default [stdout]/[stderr] logger
  const factory Logger.standard() = _DefaultLogger;

  /// Log informational output
  ///
  /// [data] should provice a valid [Object.toString()] method to ensure clean
  /// and understandable logging.
  void log(dynamic data);

  /// Log error output
  ///
  /// [data] should provice a valid [Object.toString()] method to ensure clean
  /// and understandable logging.
  void logError(dynamic error);

  /// Log the stderr of a subprocess
  ///
  /// This methods can be used to pass data of a subprocess stderr to the logger
  /// to be logged in cased such a process reports user relevant errors. This
  /// method will passivly consume the whole stream beeing passed.
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
    stderr.addStream(errStream);
  }
}
