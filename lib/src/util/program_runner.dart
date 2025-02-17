// ignore_for_file: comment_references

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';

import 'logger.dart';

// coverage:ignore-start
/// @nodoc
@internal
final programRunnerProvider = Provider(
  (ref) => ProgramRunner(logger: ref.watch(taskLoggerProvider)),
);
// coverage:ignore-end

/// @nodoc
@internal
typedef ExitCodeHandlerCb = void Function(int exitCode);

/// @nodoc
@internal
class ProgramExitException implements Exception {
  /// @nodoc
  final int exitCode;

  /// @nodoc
  final String? program;

  /// @nodoc
  final List<String>? arguments;

  /// @nodoc
  const ProgramExitException(this.exitCode, [this.program, this.arguments]);

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

/// @nodoc
@internal
class ProgramRunner {
  final TaskLogger _logger;

  /// @nodoc
  const ProgramRunner({required TaskLogger logger}) : _logger = logger;

  /// @nodoc
  Stream<String> stream(
    String program,
    List<String> arguments, {
    String? workingDirectory,
    bool failOnExit = true,
    bool runInShell = false,
    ExitCodeHandlerCb? exitCodeHandler,
  }) async* {
    Future<void>? errLog;
    try {
      _logger.debug('Streaming: $program ${arguments.join(' ')}');
      final process = await Process.start(
        program,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: runInShell,
      );
      errLog = _logger.pipeStderr(process.stderr);
      yield* process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      final processExitCode = await process.exitCode;
      _logger.debug('$program finished with exit code: $processExitCode');
      if (exitCodeHandler != null) {
        exitCodeHandler(processExitCode);
      }
      if (failOnExit) {
        if (processExitCode != 0) {
          throw ProgramExitException(processExitCode, program, arguments);
        }
      }
    } finally {
      await errLog;
    }
  }

  /// @nodoc
  Future<int> run(
    String program,
    List<String> arguments, {
    String? workingDirectory,
    bool failOnExit = false,
    bool runInShell = false,
  }) async {
    Future<void>? errLog;
    try {
      _logger.debug('Running: $program ${arguments.join(' ')}');
      final process = await Process.start(
        program,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: runInShell,
      );
      errLog = _logger.pipeStderr(process.stderr);
      await process.stdout.drain<void>();

      final processExitCode = await process.exitCode;
      _logger.debug('$program finished with exit code: $processExitCode');
      if (failOnExit) {
        if (processExitCode != 0) {
          throw ProgramExitException(processExitCode, program, arguments);
        }
      }

      return processExitCode;
    } finally {
      await errLog;
    }
  }
}
