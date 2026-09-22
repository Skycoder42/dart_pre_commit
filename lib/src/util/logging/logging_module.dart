import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

import '../logger.dart';

@internal
@immutable
@singleton
class LogLevelFactory([@ignoreParam LogLevel? logLevel]) {
  static LogLevel logLevel = .nothing;

  this {
    if (logLevel != null) {
      LogLevelFactory.logLevel = logLevel;
    }
  }

  LogLevel call() => logLevel;
}

/// @nodoc
@internal
@module
// Analyzer bug: fails to associate the doc comment above with this
// primary-constructor class; the class is documented.
// ignore: public_member_api_docs
abstract class LoggingModule() {
  @singleton
  TaskLogger taskLogger(Logger logger) => logger;
}
