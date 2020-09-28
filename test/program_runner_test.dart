import 'dart:io';

import 'package:dart_lint_hooks/src/logger.dart';
import 'package:dart_lint_hooks/src/program_runner.dart';
import 'package:dart_lint_hooks/src/task_error.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  final mockLogger = MockLogger();

  ProgramRunner sut;

  setUp(() {
    reset(mockLogger);

    sut = ProgramRunner(mockLogger);
  });

  Future<int> _run(List<String> args) => Platform.isWindows
      ? sut.run("cmd", ["/c", ...args])
      : sut.run("bash", ["-c", ...args]);

  Stream<String> _stream(List<String> args) => Platform.isWindows
      ? sut.stream("cmd", ["/c", ...args])
      : sut.stream("bash", ["-c", ...args]);

  test("run forwards exit code", () async {
    final exitCode = await _run(const ["exit 42"]);
    expect(exitCode, 42);
  });

  group("stream", () {
    test("forwards output", () async {
      final res = await _stream(const [
        "echo a && echo b && echo c",
      ]).map((e) => e.trim()).toList();
      expect(res, const ["a", "b", "c"]);
    });

    test("throws error if exit code indicates so", () async {
      final stream = _stream(const [
        "echo a && echo b && false",
      ]);
      expect(() => stream.last, throwsA(isA<TaskError>()));
    });
  });
}
