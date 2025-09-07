import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

import 'program_runner.dart';

/// @nodoc
@internal
@injectable
class ProgramDetector {
  /// @nodoc
  static const defaultTestArguments = ['--version'];

  final ProgramRunner _programRunner;

  /// @nodoc
  ProgramDetector(this._programRunner);

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
