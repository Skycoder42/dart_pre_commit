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

  test("run forwards exit code", () async {
    final exitCode = await sut.run("bash", const ["-c", "exit 42"]);
    expect(exitCode, 42);
  });

  group("stream", () {
    test("forwards output", () async {
      final res = await sut.stream("bash", const [
        "-c",
        "echo a ; echo b ; echo c",
      ]).toList();
      expect(res, const ["a", "b", "c"]);
    });

    test("throws error if exit code indicates so", () async {
      final stream = sut.stream("bash", const [
        "-c",
        "echo a ; echo b; false",
      ]);
      expect(() => stream.last, throwsA(isA<TaskError>()));
    });
  });
}
