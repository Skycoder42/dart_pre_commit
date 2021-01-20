import 'dart:async';
import 'dart:io';

import 'package:dart_pre_commit/src/logger.dart';
import 'package:dart_pre_commit/src/program_runner.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'program_runner_test.mocks.dart';

@GenerateMocks([], customMocks: [
  MockSpec<TaskLogger>(returnNullOnMissingStub: true),
])
void main() {
  final mockLogger = MockTaskLogger();

  late ProgramRunner sut;

  setUp(() {
    reset(mockLogger);

    when(mockLogger.pipeStderr(any)).thenAnswer((i) async {});

    sut = ProgramRunner(
      logger: mockLogger,
    );
  });

  Future<int> _run(List<String> args) => Platform.isWindows
      ? sut.run('cmd', ['/c', ...args])
      : sut.run('bash', ['-c', ...args]);

  Stream<String> _stream(List<String> args) => Platform.isWindows
      ? sut.stream('cmd', ['/c', ...args])
      : sut.stream('bash', ['-c', ...args]);

  test('run forwards exit code', () async {
    final exitCode = await _run(const ['exit 42']);
    expect(exitCode, 42);
  });

  group('stream', () {
    test('forwards output', () async {
      final res = await _stream(const [
        'echo a && echo b && echo c',
      ]).map((e) => e.trim()).toList();
      expect(res, const ['a', 'b', 'c']);
    });

    test('throws error if exit code indicates so', () async {
      const args = [
        'echo a && echo b && false',
      ];
      final stream = _stream(args);
      expect(() => stream.last, throwsA(predicate((e) {
        expect(e, isA<ProgramExitException>());
        final exception = e as ProgramExitException;
        expect(exception.exitCode, 1);
        expect(exception.program, Platform.isWindows ? 'cmd' : 'bash');
        expect(
          exception.arguments,
          Platform.isWindows ? ['/c', ...args] : ['-c', ...args],
        );
        return true;
      })));
    });
  });
}
