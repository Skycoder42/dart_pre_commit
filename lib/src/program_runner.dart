import 'dart:convert';
import 'dart:io';

import 'logger.dart';
import 'task_error.dart';

class ProgramRunner {
  final Logger _logger;

  const ProgramRunner(this._logger);

  Stream<String> stream(
    String program,
    List<String> arguments, {
    bool failOnExit = true,
  }) async* {
    final process = await Process.start(program, arguments);
    _logger.pipeStderr(process.stderr);
    yield* process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    if (failOnExit) {
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw TaskError("$program failed with exit code $exitCode");
      }
    }
  }

  Future<int> run(
    String program,
    List<String> arguments,
  ) async {
    final process = await Process.start(program, arguments);
    _logger.pipeStderr(process.stderr);
    process.stdout.drain<void>();
    return process.exitCode;
  }
}
