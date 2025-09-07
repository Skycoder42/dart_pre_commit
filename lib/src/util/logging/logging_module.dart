import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

import '../logger.dart';

@internal
@module
abstract class LoggingModule {
  @singleton
  TaskLogger taskLogger(Logger logger) => logger;
}
