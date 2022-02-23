import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:riverpod/riverpod.dart';

const disabledOutdatedLevel = 'disabled';

/// @nodoc
void main(List<String> args) {
  _run(args).then((c) => exitCode = c);
}

Future<int> _run(List<String> args) async {
  final di = ProviderContainer();
  final parser = ArgParser()
    ..addSeparator('Task selection:')
    ..addFlag(
      'format',
      abbr: 'f',
      defaultsTo: true,
      help: 'Format staged files with dart format.',
    )
    ..addFlag(
      'analyze',
      abbr: 'a',
      defaultsTo: true,
      help: 'Run dart analyze to find issue for the staged files.',
    )
    ..addFlag(
      'test-imports',
      abbr: 't',
      defaultsTo: true,
      help: 'Runs dart_test_tools TestImportLinter on all staged files.',
    )
    ..addFlag(
      'flutter-compat',
      abbr: 'u',
      defaultsTo: null,
      help: 'Check if the package can be added to a flutter project without '
          'breaking the flutter dependency constraints. This task is run by '
          'default only if the current package is not a flutter package.',
    )
    ..addOption(
      'outdated',
      abbr: 'o',
      allowed: OutdatedLevel.values
          .map((e) => e.name)
          .followedBy([disabledOutdatedLevel]),
      defaultsTo: OutdatedLevel.any.name,
      help: 'Enables the outdated packages check. You can choose one of the '
          'levels described below to require certain package updates. If they '
          'are not met, the hook will fail. No matter what level, as long as '
          'it is not disabled - which will completely disable the hook - it '
          'will still print available package updates without failing.',
      valueHelp: 'level',
      allowedHelp: {
        disabledOutdatedLevel: 'Do not run the hook.',
        OutdatedLevel.none.name:
            'Only print recommended updates, do not require any.',
        OutdatedLevel.major.name:
            'Only require major updates, e.g. 1.X.Y-Z to 2.0.0-0.',
        OutdatedLevel.minor.name:
            'Only require minor updates, e.g. 1.0.X-Y to 1.1.0-0.',
        OutdatedLevel.patch.name:
            'Only require patch updates, e.g. 1.0.0-X to 1.0.1-0.',
        OutdatedLevel.any.name: 'Require all updates that are available.',
      },
    )
    ..addFlag(
      'check-pull-up',
      abbr: 'p',
      defaultsTo: true,
      help: 'Check if direct dependencies in the pubspec.lock have '
          'higher versions then specified in pubspec.yaml and warn if '
          "that's the case.",
    )
    ..addFlag(
      'continue-on-rejected',
      abbr: 'c',
      help: 'Continue checks even if a task rejects a certain file. The whole '
          'hook will still exit with rejected, but only after all files have '
          'been processed.',
    )
    ..addSeparator('Other:')
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
      defaultsTo: di.read(HooksProviderInternal.ansiSupportedProvider),
      help: 'When enabled, a rich, ANSI-backed output is used. If disabled, '
          'a simple logger is used, which is optimized for logging to files. '
          'The mode is auto-detected, but might not detect all terminals '
          'correctly. In this case, you can use this option to set it '
          'explicitly.',
    )
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

  try {
    final options = parser.parse(args);
    if (options['help'] as bool) {
      stdout.writeln(parser.usage);
      return 0;
    }

    final dir = options['directory'] as String?;
    if (dir != null) {
      Directory.current = dir;
    }

    di.read(HooksProviderInternal.ansiSupportedProvider.notifier).state =
        options['ansi'] as bool;
    di.read(HooksProviderInternal.configFilePathProvider.notifier).state =
        options.options.contains('config-path')
            ? File(options['config-path'] as String)
            : null;

    final outdatedLevel = options['outdated'] as String;
    final hooks = await di.read(
      HooksProvider.hookProvider(
        HooksConfig(
          format: options['format'] as bool,
          analyze: options['analyze'] as bool,
          testImports: options['test-imports'] as bool,
          outdated: outdatedLevel == disabledOutdatedLevel
              ? null
              : OutdatedLevel.values.byName(outdatedLevel),
          pullUpDependencies: options['check-pull-up'] as bool,
          flutterCompat:
              options['flutter-compat'] as bool? ?? !(await _isFlutter(di)),
          continueOnRejected: options['continue-on-rejected'] as bool,
        ),
      ).future,
    );
    hooks.logger.logLevel = LogLevel.values.byName(
      options['log-level'] as String,
    );

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
    di.read(HooksProviderInternal.taskLoggerProvider).except(e, s);
    return 127;
  } finally {
    di.dispose();
  }
}

Future<bool> _isFlutter(ProviderContainer di) async {
  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    di
        .read(HooksProviderInternal.loggerProvider)
        .warn('No pubspec.yaml file in ${Directory.current.path}');
    return false;
  }

  final pubspecString = await pubspecFile.readAsString();
  final pubspec = Pubspec.parse(pubspecString, sourceUrl: pubspecFile.uri);

  return pubspec.dependencies.containsKey('flutter');
}
