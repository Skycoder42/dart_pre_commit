import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import 'logger.dart';

Stream<String> runProgram(
  String program,
  List<String> arguments, {
  @required Logger logger,
  bool failOnExit = true,
}) async* {
  final process = await Process.start(program, arguments);
  logger.pipeStderr(process.stderr);
  if (failOnExit) {
    process.exitCode.then((code) {
      if (code != 0) {
        exit(code);
      }
    });
  }
  yield* process.stdout.transform(utf8.decoder).transform(const LineSplitter());
}
