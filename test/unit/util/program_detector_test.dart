import 'dart:io';

import 'package:dart_pre_commit/src/util/program_detector.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/dart_test_tools.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockProgramRunner extends Mock implements ProgramRunner {}

void main() {
  group('$ProgramDetector', () {
    const testProgram = 'test-program';
    const testArgs = ['-get', 'version'];

    final mockProgramRunner = MockProgramRunner();

    late ProgramDetector sut;

    setUp(() {
      reset(mockProgramRunner);

      when(
        () => mockProgramRunner.run(
          any(),
          any(),
          runInShell: any(named: 'runInShell'),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).thenReturnAsync(0);

      sut = ProgramDetector(mockProgramRunner);
    });

    group('hasProgram', () {
      test('calls program runner with default arguments', () async {
        final result = await sut.hasProgram(testProgram);

        expect(result, isTrue);

        verify(
          () => mockProgramRunner.run(
            testProgram,
            ProgramDetector.defaultTestArguments,
            workingDirectory: Directory.systemTemp.path,
          ),
        );
      });

      test('calls program runner with custom arguments', () async {
        final result = await sut.hasProgram(
          testProgram,
          testArguments: testArgs,
          searchInShell: true,
        );

        expect(result, isTrue);

        verify(
          () => mockProgramRunner.run(
            testProgram,
            testArgs,
            runInShell: true,
            workingDirectory: Directory.systemTemp.path,
          ),
        );
      });

      test('returns false if starting the process fails', () async {
        when(
          () => mockProgramRunner.run(
            any(),
            any(),
            runInShell: any(named: 'runInShell'),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenThrow(Exception('Failed to start process'));

        final result = await sut.hasProgram(testProgram);

        expect(result, isFalse);

        verify(
          () => mockProgramRunner.run(
            testProgram,
            ProgramDetector.defaultTestArguments,
            workingDirectory: Directory.systemTemp.path,
          ),
        );
      });
    });
  });
}
