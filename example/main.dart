import 'dart:io';

import "package:dart_pre_commit/dart_pre_commit.dart";

Future<void> main(List<String> arguments) async {
  // assume first arg is the git directory to handle
  Directory.current = arguments.first;

  // create the hooks instance with your custom configuration
  final hook = await Hooks.create();

  // run all hooks
  final result = await hook();

  // report the result
  exitCode = result.index;
}
