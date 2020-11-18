// ignore_for_file: lines_longer_than_80_chars
/// Documentation of the dart_pre_commit binary
///
/// You can run this script via `dart pub run dart_pre_commit [options]`. It
/// will create an instance of [Hooks] and invoke it to perform the pre commit
/// hooks. Check the documentation of the [Hooks] class for more details on what
/// the sepecific hooks do.
///
/// In order to be able to configure how the hooks should be run, you can
/// specify command line arguments to the script. The following tables list all
/// available options, organized into the same groups as shown when running
/// `dart pub run dart_pre_commit --help`.
///
/// ### Parsing Options
///  Option                          | Default | Description
/// ---------------------------------|---------|-------------
/// `-i`, `--[no-]fix-imports`       | on      | Format and sort imports of staged files.
/// `-f`, `--[no-]format`            | on      | Format staged files with dart format.
/// `-a`, `--[no-]analyze`           | on      | Run dart analyze to find issue for the staged files.
/// `-p`, `--[no-]check-pull-up`     | off     | Check if direct dependencies in the pubspec.lock have higher versions then specified in pubspec.yaml and warn if that's the case.
/// `-c`, `--[no-]continue-on-error` | off     | Continue checks even if a task fails for a certain file. The whole hook will still fail, but only after all files have been processed
///
/// ### Other
///  Option                           | Default             | Description
/// ----------------------------------|---------------------|-------------
/// `-d`, `--directory=<dir>`         | `Directory.current` | Set the directory to run this command in. By default, it will run in the current working directory.
/// `-e`, `--[no-]detailed-exit-code` | off                 | Instead of simply 0/1 as exit code for 'commit ok' or 'commit needs user intervention', output exit codes according to the full hook result (See [HookResult]).
/// `-v`, `--version`                 | -                   | Show the version of the dart_pre_commit package.
/// `-h`, `--help`                    | -                   | Show this help.
library dart_pre_commit_bin;

import 'dart:io';

import 'package:args/args.dart'; // ignore: import_of_legacy_library_into_null_safe
import 'package:dart_pre_commit/dart_pre_commit.dart';

/// @nodoc
void main(List<String> args) {
  _run(args).then((c) => exitCode = c);
}

Future<int> _run(List<String> args) async {
  final parser = ArgParser()
    ..addSeparator('Parsing Options:')
    ..addFlag(
      'fix-imports',
      abbr: 'i',
      defaultsTo: true,
      help: 'Format and sort imports of staged files.',
    )
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
      'check-pull-up',
      abbr: 'p',
      help: 'Check if direct dependencies in the pubspec.lock have '
          'higher versions then specified in pubspec.yaml and warn if '
          'that´s the case.',
    )
    ..addFlag(
      'continue-on-error',
      abbr: 'c',
      help:
          'Continue checks even if a task fails for a certain file. The whole '
          'hook will still fail, but only after all files have been processed.',
    )
    ..addSeparator('Other:')
    ..addOption(
      'directory',
      abbr: 'd',
      help: 'Set the directory to run this command in. By default, it will run '
          'in the current working directory.',
      valueHelp: 'dir',
    )
    ..addFlag(
      'detailed-exit-code',
      abbr: 'e',
      help: 'Instead of simply 0/1 as exit code for "commit ok" or "commit '
          'needs user intervention", output exit codes according to the full '
          'hook result (See HookResult).',
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
      stdout.write(parser.usage);
      return 0;
    }

    final dir = options['directory'] as String?;
    if (dir != null) {
      Directory.current = dir;
    }

    final hooks = await Hooks.create(
      fixImports: options['fix-imports'] as bool,
      format: options['format'] as bool,
      analyze: options['analyze'] as bool,
      pullUpDependencies: options['check-pull-up'] as bool,
      continueOnError: options['continue-on-error'] as bool,
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
    return 127;
  }
}
