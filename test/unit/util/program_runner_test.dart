import 'dart:async';
import 'dart:io';

import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockTaskLogger extends Mock implements TaskLogger {}

void main() {
  final mockLogger = MockTaskLogger();

  late ProgramRunner sut;

  TypeMatcher<ProgramExitException> isAProgramException(
    List<String> args,
    int exitCode,
  ) => isA<ProgramExitException>()
      .having((e) => e.exitCode, 'exitCode', exitCode)
      .having((e) => e.program, 'program', Platform.isWindows ? 'cmd' : 'bash')
      .having(
        (e) => e.arguments,
        'arguments',
        Platform.isWindows ? ['/c', ...args] : ['-c', ...args],
      );

  setUpAll(() {
    registerFallbackValue(const Stream<List<int>>.empty());
  });

  setUp(() {
    reset(mockLogger);

    when(() => mockLogger.pipeStderr(any())).thenAnswer((i) async {});

    sut = ProgramRunner(mockLogger);
  });

  Future<int> run(
    List<String> args, {
    bool failOnExit = false,
    String? workingDirectory,
  }) => Platform.isWindows
      ? sut.run(
          'cmd',
          ['/c', ...args],
          failOnExit: failOnExit,
          workingDirectory: workingDirectory,
        )
      : sut.run(
          'bash',
          ['-c', ...args],
          failOnExit: failOnExit,
          workingDirectory: workingDirectory,
        );

  Stream<String> runStream(
    List<String> args, {
    bool failOnExit = true,
    ExitCodeHandlerCb? handler,
    String? workingDirectory,
  }) => Platform.isWindows
      ? sut.stream(
          'cmd',
          ['/c', ...args],
          failOnExit: failOnExit,
          exitCodeHandler: handler,
          workingDirectory: workingDirectory,
        )
      : sut.stream(
          'bash',
          ['-c', ...args],
          failOnExit: failOnExit,
          exitCodeHandler: handler,
          workingDirectory: workingDirectory,
        );

  group('run', () {
    test('forwards exit code', () async {
      final exitCode = await run(const ['exit 42']);
      expect(exitCode, 42);
    });

    test('throws on unexpected exit code if enabled', () {
      const args = ['exit 42'];
      expect(
        () => run(args, failOnExit: true),
        throwsA(isAProgramException(args, 42)),
      );
    });

    test('fail on exit ignores success codes', () async {
      final exitCode = await run(const ['exit 0'], failOnExit: true);
      expect(exitCode, 0);
    });

    test('runs in working directory', () async {
      final exitCode = await run(
        Platform.isWindows ? const ['cd'] : const ['pwd'],
        workingDirectory: Directory.systemTemp.path,
      );
      expect(exitCode, 0);
    });
  });

  group('stream', () {
    test('forwards output', () {
      final res = runStream(const ['echo a && echo b && echo c']);
      expect(
        res,
        emitsInOrder(<dynamic>[
          startsWith('a'),
          startsWith('b'),
          startsWith('c'),
          emitsDone,
        ]),
      );
    });

    test('throws error if exit code indicates so', () {
      const args = ['echo a && echo b && false'];
      final stream = runStream(args);
      expect(
        stream,
        emitsInOrder(<dynamic>[
          startsWith('a'),
          startsWith('b'),
          emitsError(isAProgramException(args, 1)),
          emitsDone,
        ]),
      );
    });

    test('Does not throw if failOnExit is false', () {
      const args = ['echo a && echo b && false'];
      final stream = runStream(args, failOnExit: false);
      expect(
        stream,
        emitsInOrder(<dynamic>[startsWith('a'), startsWith('b'), emitsDone]),
      );
    });

    test('Reports exit code via callback', () {
      const args = ['echo a && echo b && exit 42'];
      final stream = runStream(
        args,
        failOnExit: false,
        handler: expectAsync1<void, int>((exitCode) {
          expect(exitCode, 42);
        }),
      );
      expect(
        stream,
        emitsInOrder(<dynamic>[startsWith('a'), startsWith('b'), emitsDone]),
      );
    });

    test('runs in working directory', () async {
      final stream = runStream(
        Platform.isWindows ? const ['cd'] : const ['pwd'],
        workingDirectory: Directory.systemTemp.path,
      );

      expect(
        stream,
        emitsInOrder(<dynamic>[
          if (Platform.isMacOS)
            await Directory.systemTemp.resolveSymbolicLinks()
          else
            Directory.systemTemp.path,
          emitsDone,
        ]),
      );
    });
  });

  testData<(ProgramExitException, String)>(
    'ProgramExitException shows correct error message',
    const [
      (ProgramExitException(42), 'A subprocess failed with exit code 42'),
      (ProgramExitException(13, 'dart'), 'dart failed with exit code 13'),
      (
        ProgramExitException(7, 'dart', ['some', 'args']),
        '"dart some args" failed with exit code 7',
      ),
    ],
    (fixture) {
      expect(fixture.$1.toString(), fixture.$2);
    },
  );
}
