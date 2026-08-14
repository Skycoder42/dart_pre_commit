import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

import '../logger.dart';

@internal
@immutable
@singleton
class LogLevelFactory {
  static LogLevel logLevel = .nothing;

  new([@ignoreParam LogLevel? logLevel]) {
    if (logLevel != null) {
      LogLevelFactory.logLevel = logLevel;
    }
  }

  LogLevel call() => logLevel;
}

@internal
@module
abstract class LoggingModule {
  @singleton
  TaskLogger taskLogger(Logger logger) => logger;
}
