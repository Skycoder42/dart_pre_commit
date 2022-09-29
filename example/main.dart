import 'dart:io';

import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:dart_pre_commit/src/tasks/provider/task_loader.dart';
import 'package:riverpod/riverpod.dart';

Future<void> main(List<String> arguments) async {
  // assume first arg is the git directory to handle
  Directory.current = arguments.first;

  // create an IoC-Container for easier initialization of the hooks
  final container = ProviderContainer();

  // load the configuration
  await container.read(configLoaderProvider).loadGlobalConfig();

  // register tasks you want to run
  container.read(taskLoaderProvider)
    ..registerConfigurableTask(formatTaskProvider)
    ..registerTask(analyzeTaskProvider);

  // obtain the hooks instance from the IoC
  final hooks = container.read(hooksProvider(const HooksConfig()));

  // run all hooks
  final result = await hooks();

  // report the result
  exitCode = result.isSuccess ? 0 : 1;
}
