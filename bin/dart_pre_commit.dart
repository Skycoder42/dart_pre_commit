import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:riverpod/riverpod.dart';

const disabledOutdatedLevel = 'disabled';

/// @nodoc
Future<void> main(List<String> args) async {
  exitCode = await _run(args);
}

Future<int> _run(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'continue-on-rejected',
      abbr: 'c',
      help: 'Continue checks even if a task rejects a certain file. The whole '
          'hook will still exit with rejected, but only after all files have '
          'been processed.',
    )
    ..addOption(
      'directory',
      abbr: 'd',
      help: 'Set the directory to run this command in. By default, it will run '
          'in the current working directory.',
      valueHelp: 'dir',
    )
    ..addOption(
      'config-path',
      abbr: 'n',
      help: 'Use the specified config for configuring the tool instead of '
          'loading the config from the pubspec.yaml.',
      valueHelp: 'path',
    )
    ..addFlag(
      'detailed-exit-code',
      abbr: 'e',
      help: 'Instead of simply 0/1 as exit code for "commit ok" or "commit '
          'needs user intervention", output exit codes according to the full '
          'hook result (See HookResult).',
    )
    ..addOption(
      'log-level',
      abbr: 'l',
      allowed: LogLevel.values.map((e) => e.name),
      defaultsTo: LogLevel.info.name,
      help: 'Specify the logging level for task logs. This only affects log '
          'details of tasks, not the status update message. The levels are:',
      valueHelp: 'level',
      allowedHelp: {
        LogLevel.debug.name: 'Print all messages.',
        LogLevel.info.name: 'Print informational messages.',
        LogLevel.warn.name: 'Print warnings and errors only.',
        LogLevel.error.name: 'Print errors only.',
        LogLevel.except.name: 'Print exceptions only.',
        LogLevel.nothing.name: 'Print nothing at all.',
      },
    )
    ..addFlag(
      'ansi',
      defaultsTo: stdout.hasTerminal && stdout.supportsAnsiEscapes,
      help: 'When enabled, a rich, ANSI-backed output is used. If disabled, '
          'a simple logger is used, which is optimized for logging to files. '
          'The mode is auto-detected, but might not detect all terminals '
          'correctly. In this case, you can use this option to set it '
          'explicitly.',
    )
    ..addSeparator('Other:')
    ..addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Show the version of the dart_pre_commit package.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help.',
    );

  ProviderContainer? di;
  try {
    // parse command line options
    final options = parser.parse(args);
    if (options['help'] as bool) {
      stdout.writeln(parser.usage);
      return 0;
    }

    // change working directory if given
    final dir = options['directory'] as String?;
    if (dir != null) {
      Directory.current = dir;
    }

    // setup dependency injection container
    final ansiSupported = options['ansi'] as bool;
    final logLevel = LogLevel.values.byName(options['log-level'] as String);
    di = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithProvider(
          Provider(
            (ref) => ansiSupported
                ? ref.watch(consoleLoggerProvider(logLevel))
                : ref.watch(simpleLoggerProvider(logLevel)),
          ),
        ),
      ],
    );

    // register tasks
    await di.read(defaultTasksLoaderProvider).registerDefaultTasks();

    // load hooks instance
    final hooks = di.read(
      hooksProvider(
        HooksConfig(
          configFile: options['config-path'] as String?,
          continueOnRejected: options['continue-on-rejected'] as bool,
        ),
      ),
    );

    // run hooks and return result
    final result = await hooks();
    if (options['detailed-exit-code'] as bool) {
      return result.index;
    } else {
      return result.isSuccess ? 0 : 1;
    }
  } on FormatException catch (e) {
    stderr
      ..writeln('${e.message}\n')
      ..write(parser.usage);
    return 2;
  } on Exception catch (e, s) {
    di?.read(loggerProvider).except(e, s);
    return 127;
  } finally {
    di?.dispose();
  }
}
