// coverage:ignore-file

import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart' as logging;
import 'package:riverpod/riverpod.dart';

import '../logger.dart';

// coverage:ignore-start
@internal
final loggingWrapperProvider = Provider(
  (ref) => LoggingWrapper(
    ref.watch(taskLoggerProvider),
  ),
);
// coverage:ignore-end

/// @nodoc
@internal
class LoggingWrapperException implements Exception {
  /// @nodoc
  final String message;

  /// @nodoc
  LoggingWrapperException(this.message);

  // coverage:ignore-start
  @override
  String toString() => message;
  // coverage:ignore-end
}

/// @nodoc
@internal
class LoggingWrapper implements logging.Logger {
  /// @nodoc
  final TaskLogger taskLogger;

  /// @nodoc
  const LoggingWrapper(this.taskLogger);

  @override
  logging.Level get level => logging.Level.ALL;

  @override
  set level(logging.Level? level) {}

  @override
  Map<String, logging.Logger> get children => const {};

  @override
  void clearListeners() {}

  @override
  void config(Object? message, [Object? error, StackTrace? stackTrace]) =>
      taskLogger.debug(message.toString());

  @override
  void fine(Object? message, [Object? error, StackTrace? stackTrace]) =>
      taskLogger.debug(message.toString());

  @override
  void finer(Object? message, [Object? error, StackTrace? stackTrace]) =>
      taskLogger.debug(message.toString());

  @override
  void finest(Object? message, [Object? error, StackTrace? stackTrace]) =>
      taskLogger.debug(message.toString());

  @override
  String get fullName => '';

  @override
  void info(Object? message, [Object? error, StackTrace? stackTrace]) =>
      taskLogger.info(message.toString());

  @override
  bool isLoggable(logging.Level value) => true;

  @override
  void log(
    logging.Level logLevel,
    Object? message, [
    Object? error,
    StackTrace? stackTrace,
    Zone? zone,
  ]) {
    if (logLevel >= logging.Level.SHOUT) {
      final exception = error is Exception
          ? error
          : LoggingWrapperException((error ?? message).toString());
      taskLogger.except(exception, stackTrace);
    } else if (logLevel >= logging.Level.SEVERE) {
      taskLogger.error(message.toString());
    } else if (logLevel >= logging.Level.WARNING) {
      taskLogger.warn(message.toString());
    } else if (logLevel >= logging.Level.INFO) {
      taskLogger.info(message.toString());
    } else {
      taskLogger.debug(message.toString());
    }
  }

  @override
  String get name => '';

  @override
  Stream<logging.LogRecord> get onRecord => const Stream.empty();

  @override
  logging.Logger? get parent => null;

  @override
  void severe(Object? message, [Object? error, StackTrace? stackTrace]) =>
      taskLogger.error(message.toString());

  @override
  void shout(Object? message, [Object? error, StackTrace? stackTrace]) {
    final exception = error is Exception
        ? error
        : LoggingWrapperException((error ?? message).toString());
    taskLogger.except(exception, stackTrace);
  }

  @override
  void warning(Object? message, [Object? error, StackTrace? stackTrace]) =>
      taskLogger.warn(message.toString());
}
