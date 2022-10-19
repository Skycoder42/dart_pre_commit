// ignore_for_file: comment_references

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';

import 'logger.dart';

// coverage:ignore-start
@internal
final programRunnerProvider = Provider(
  (ref) => ProgramRunner(
    logger: ref.watch(taskLoggerProvider),
  ),
);
// coverage:ignore-end

@internal
class ProgramExitException implements Exception {
  final int exitCode;

  final String? program;

  final List<String>? arguments;

  const ProgramExitException(
    this.exitCode, [
    this.program,
    this.arguments,
  ]);

  @override
  String toString() {
    String prefix;
    if (program != null) {
      if (arguments?.isNotEmpty ?? false) {
        prefix = '"$program ${arguments!.join(' ')}"';
      } else {
        prefix = program!;
      }
    } else {
      prefix = 'A subprocess';
    }
    return '$prefix failed with exit code $exitCode';
  }
}

@internal
class ProgramRunner {
  final TaskLogger logger;

  const ProgramRunner({
    required this.logger,
  });

  Stream<String> stream(
    String program,
    List<String> arguments, {
    String? workingDirectory,
    bool failOnExit = true,
    bool runInShell = false,
  }) async* {
    Future<void>? errLog;
    try {
      logger.debug('Streaming: $program ${arguments.join(' ')}');
      final process = await Process.start(
        program,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: runInShell,
      );
      errLog = logger.pipeStderr(process.stderr);
      yield* process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      if (failOnExit) {
        final exitCode = await process.exitCode;
        if (exitCode != 0) {
          throw ProgramExitException(exitCode, program, arguments);
        }
        logger.debug('$program finished with exit code: $exitCode');
      }
    } finally {
      await errLog;
    }
  }

  Future<int> run(
    String program,
    List<String> arguments, {
    String? workingDirectory,
    bool failOnExit = false,
    bool runInShell = false,
  }) async {
    Future<void>? errLog;
    try {
      logger.debug('Running: $program ${arguments.join(' ')}');
      final process = await Process.start(
        program,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: runInShell,
      );
      errLog = logger.pipeStderr(process.stderr);
      await process.stdout.drain<void>();

      final exitCode = await process.exitCode;
      if (failOnExit) {
        if (exitCode != 0) {
          throw ProgramExitException(exitCode, program, arguments);
        }
        logger.debug('$program finished with exit code: $exitCode');
      }

      return exitCode;
    } finally {
      await errLog;
    }
  }
}
