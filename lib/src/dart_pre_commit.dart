// coverage:ignore-file

import 'dart:async';
import 'dart:io';

import 'package:riverpod/riverpod.dart';

import 'hooks.dart';
import 'tasks/provider/default_tasks_loader.dart';
import 'tasks/provider/task_loader.dart';
import 'util/logger.dart';
import 'util/logging/console_logger.dart';
import 'util/logging/simple_logger.dart';

/// A configuration callback to register custom tasks
typedef RegisterTasksCallback = FutureOr<void> Function(TaskLoader taskLoader);

/// A simple static class that provides a method to simply run the pre commit
/// hooks.
abstract class DartPreCommit {
  DartPreCommit._();

  /// Runs all predefined hooks using the given [config].
  ///
  /// By default, all built in tasks are enabled. By setting
  /// [registerDefaultTasks] to false, you can disable all of them. You can also
  /// use the [registerCustomTasks] callback to register your own tasks.
  ///
  /// The [logLevel], which defaults to [LogLevel.info], can be used to
  /// configure the logging sensitivity. The [useAnsiLogger] controls how
  /// logging is done. If not specified, the logging mode is auto detected. See
  /// [ConsoleLogger] and [SimpleLogger] for more details.
  static Future<HookResult> run({
    HooksConfig config = const HooksConfig(),
    bool registerDefaultTasks = true,
    RegisterTasksCallback? registerCustomTasks,
    LogLevel logLevel = LogLevel.info,
    bool? useAnsiLogger,
  }) async {
    final di = _createProviderContainer(logLevel, useAnsiLogger);
    try {
      await _registerTasks(di, registerDefaultTasks, registerCustomTasks);
      final result = await di.read(hooksProvider(config)).call();
      return result;
    } finally {
      di.dispose();
    }
  }

  static ProviderContainer _createProviderContainer(
    LogLevel logLevel,
    bool? useAnsiLogger,
  ) {
    final ansiSupported =
        useAnsiLogger ?? (stdout.hasTerminal && stdout.supportsAnsiEscapes);

    return ProviderContainer(
      overrides: [
        loggerProvider.overrideWith(
          (ref) => ansiSupported
              ? ref.watch(consoleLoggerProvider(logLevel))
              : ref.watch(simpleLoggerProvider(logLevel)),
        ),
      ],
    );
  }

  static Future<void> _registerTasks(
    ProviderContainer di,
    bool registerDefaultTasks,
    RegisterTasksCallback? registerCustomTasks,
  ) async {
    if (registerDefaultTasks) {
      await di.read(defaultTasksLoaderProvider).registerDefaultTasks();
    }
    if (registerCustomTasks != null) {
      await registerCustomTasks(di.read(taskLoaderProvider));
    }
  }
}
