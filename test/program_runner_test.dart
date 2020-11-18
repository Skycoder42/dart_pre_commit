import 'dart:io';

import 'package:dart_pre_commit/src/logger.dart';
import 'package:dart_pre_commit/src/program_runner.dart';
import 'package:dart_pre_commit/src/task_exception.dart';
import 'package:mockito/annotations.dart'; // ignore: import_of_legacy_library_into_null_safe
import 'package:mockito/mockito.dart'; // ignore: import_of_legacy_library_into_null_safe
import 'package:test/test.dart';

import 'program_runner_test.mocks.dart';

@GenerateMocks([Logger])
void main() {
  final mockLogger = MockLogger();

  late ProgramRunner sut;

  setUp(() {
    reset(mockLogger);

    when(mockLogger.pipeStderr(any)).thenReturn(null);

    sut = ProgramRunner(mockLogger);
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
      final stream = _stream(const [
        'echo a && echo b && false',
      ]);
      expect(() => stream.last, throwsA(isA<TaskException>()));
    });
  });
}
