// ignore_for_file: comment_references

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'logger.dart';

/// An exception that gets thrown if a subprocess exits with an unexpected code.
class ProgramExitException implements Exception {
  /// The exit code of the process.
  final int exitCode;

  /// The program that was executed.
  final String? program;

  /// The arguments that were passed to the program.
  final List<String>? arguments;

  /// Default constructor.
  ///
  /// The [exitCode] is always required, but [program] and [arguments] are
  /// optional. If [arguments] are specified but [program] is not, the arguments
  /// are ignored.
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

/// A helper class to run subprocesses easily.
class ProgramRunner {
  /// The [TaskLogger] instance used by this task.
  final TaskLogger logger;

  /// Default constructor.
  const ProgramRunner({
    required this.logger,
  });

  /// Runs a program and streams the output, line by line.
  ///
  /// This will start [program] with [arguments] and run the process in the
  /// background. The standard output of the process is decoded using the
  /// [utf8.decoder] and streamed line by line. The standard error is forwarded
  /// to the [logger]. If [workingDirectory] is set, the process will be
  /// launched in that directory. Otherwise it will run in [Directory.current].
  /// The [runInShell] parameter is simply passed to [Process.start] as is.
  ///
  /// If [failOnExit] is true, the method will throw a [ProgramExitException] if
  /// the program exists with anything but 0.
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

  /// Runs a program until exited and returns the exit code.
  ///
  /// This will start [program] with [arguments] and run the process in the
  /// background. The standard output of the process is discarded, as only the
  /// exit code is needed.The standard error is forwarded to the [logger]. If
  /// [workingDirectory] is set, the process will be launched in that directory.
  /// Otherwise it will run in [Directory.current]. The [runInShell] parameter
  /// is simply passed to [Process.start] as is.
  ///
  /// If [failOnExit] is true, the method will throw a [ProgramExitException] if
  /// the program exists with anything but 0.
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
