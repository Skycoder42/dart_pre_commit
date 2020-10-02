import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_pre_commit/dart_pre_commit.dart';

void main(List<String> args) {
  _run(args).then((c) => exitCode = c);
}

Future<int> _run(List<String> args) async {
  final parser = ArgParser()
    ..addSeparator("Parsing Options:")
    ..addFlag(
      "fix-imports",
      abbr: "i",
      defaultsTo: true,
      help: "Format and sort imports of staged files.",
    )
    ..addFlag(
      "format",
      abbr: "f",
      defaultsTo: true,
      help: "Format staged files with dartfmt.",
    )
    ..addFlag(
      "analyze",
      abbr: "a",
      defaultsTo: true,
      help: "Run dartanalyzer to find issue for the staged files.",
    )
    ..addFlag(
      "continue-on-error",
      abbr: "c",
      help:
          "Continue checks even if a task fails for a certain file. The whole hook will still fail, but only after all files have been processed.",
    )
    ..addSeparator("Other:")
    ..addOption(
      "directory",
      abbr: "d",
      help:
          "Set the directory to run this command in. By default, it will run in the current working directory.",
      valueHelp: "dir",
    )
    ..addFlag(
      "detailed-exit-code",
      abbr: "e",
      help:
          "Instead of simply 0/1 as exit code for 'commit ok' or 'commit needs user intervention', output exit codes according to the full hook result (See HookResult).",
    )
    ..addFlag(
      "version",
      abbr: "v",
      negatable: false,
      help: "Show the version of the dart_pre_commit package.",
    )
    ..addFlag(
      "help",
      abbr: "h",
      negatable: false,
      help: "Show this help.",
    );

  try {
    final options = parser.parse(args);
    if (options["help"] as bool) {
      stdout.write(parser.usage);
      return 0;
    }

    final dir = options["directory"] as String;
    if (dir != null) {
      Directory.current = dir;
    }

    final hooks = await Hooks.create(
      fixImports: options["fix-imports"] as bool,
      format: options["format"] as bool,
      analyze: options["analyze"] as bool,
      continueOnError: options["continue-on-error"] as bool,
    );

    final result = await hooks();
    if (options["detailed-exit-code"] as bool) {
      return result.index;
    } else {
      return result.isSuccess ? 0 : 1;
    }
  } on FormatException catch (e) {
    stderr.writeln("${e.message}\n");
    stderr.write(parser.usage);
    return 127;
  }
}
