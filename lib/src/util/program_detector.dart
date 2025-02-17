import 'dart:io';

import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';

import 'program_runner.dart';

// coverage:ignore-start
/// @nodoc
@internal
final programDetectorProvider = Provider(
  (ref) => ProgramDetector(programRunner: ref.watch(programRunnerProvider)),
);
// coverage:ignore-end

/// @nodoc
@internal
class ProgramDetector {
  /// @nodoc
  static const defaultTestArguments = ['--version'];

  final ProgramRunner _programRunner;

  /// @nodoc
  ProgramDetector({required ProgramRunner programRunner})
    : _programRunner = programRunner;

  /// @nodoc
  Future<bool> hasProgram(
    String program, {
    List<String> testArguments = defaultTestArguments,
    bool searchInShell = false,
  }) async {
    try {
      await _programRunner.run(
        program,
        testArguments,
        runInShell: searchInShell,
        workingDirectory: Directory.systemTemp.path,
      );
      return true;
    } on Exception {
      return false;
    }
  }
}
