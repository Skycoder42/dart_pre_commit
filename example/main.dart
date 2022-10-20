import 'dart:io';

import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:riverpod/riverpod.dart';

Future<void> main(List<String> arguments) async {
  // assume first arg is the git directory to handle
  Directory.current = arguments.first;

  // create an IoC-Container for easier initialization of the hooks
  final container = ProviderContainer(
    overrides: [
      loggerProvider.overrideWithProvider(simpleLoggerProvider(LogLevel.info)),
    ],
  );

  // register tasks you want to run
  await container.read(defaultTasksLoaderProvider).registerDefaultTasks();

  // obtain the hooks instance from the IoC
  final hooks = container.read(hooksProvider(const HooksConfig()));

  // run all hooks
  final result = await hooks();

  // report the result
  exitCode = result.isSuccess ? 0 : 1;
}
