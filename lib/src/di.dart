import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

import 'di.config.dart';
import 'util/logger.dart';
import 'util/logging/console_logger.dart';
import 'util/logging/simple_logger.dart';

@internal
@InjectableInit(
  preferRelativeImports: true,
  throwOnMissingDependencies: true,
  ignoreUnregisteredTypes: [GetIt, LogLevel],
)
GetIt createDiContainer({
  bool useAnsiLogger = false,
  LogLevel logLevel = LogLevel.info,
}) {
  final instance = GetIt.asNewInstance();
  instance
    ..registerSingleton(instance)
    ..registerSingleton(logLevel);
  return instance.init(
    environment: useAnsiLogger ? ansiEnv.name : noAnsiEnv.name,
  );
}
