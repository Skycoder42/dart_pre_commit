import 'dart:io';

import 'package:dart_pre_commit/src/dart_pre_commit.dart';

Future<void> main(List<String> arguments) async {
  // assume first arg is the git directory to handle
  Directory.current = arguments.first;

  // Run all hooks
  final result = await DartPreCommit.run();

  // report the result
  exitCode = result.isSuccess ? 0 : 1;
}
