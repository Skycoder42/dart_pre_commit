import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_pre_commit/src/logger.dart';

import 'task_exception.dart';

class ProgramRunner {
  final TaskLogger logger;

  const ProgramRunner({
    required this.logger,
  });

  Stream<String> stream(
    String program,
    List<String> arguments, {
    bool failOnExit = true,
  }) async* {
    Future<void>? errLog;
    try {
      final process = await Process.start(program, arguments);
      errLog = logger.pipeStderr(process.stderr);
      yield* process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      if (failOnExit) {
        final exitCode = await process.exitCode;
        if (exitCode != 0) {
          throw TaskException('$program failed with exit code $exitCode');
        }
      }
    } finally {
      await errLog;
    }
  }

  Future<int> run(
    String program,
    List<String> arguments,
  ) async {
    Future<void>? errLog;
    try {
      final process = await Process.start(program, arguments);
      errLog = logger.pipeStderr(process.stderr);
      await process.stdout.drain<void>();
      return await process.exitCode;
    } finally {
      await errLog;
    }
  }
}
