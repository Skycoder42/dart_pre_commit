import 'dart:io';

import 'package:dart_lint_hooks/src/analyze.dart';
import 'package:dart_lint_hooks/src/logger.dart';
import 'package:dart_lint_hooks/src/program_runner.dart';
import 'package:dart_lint_hooks/src/task_error.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

import 'format_test.dart';

class MockLogger extends Mock implements Logger {}

class MockProgramRunner extends Mock implements ProgramRunner {}

void main() {
  final mockLogger = MockLogger();
  final mockRunner = MockRunner();

  setUp(() {
    reset(mockLogger);
    reset(mockRunner);

    when(mockRunner.stream(any, any))
        .thenAnswer((_) => Stream.fromIterable(const []));
  });

  test("Run dartanalyzer with correct arguments", () async {
    final sut = Analyze(
      files: const [],
      logger: mockLogger,
      runner: mockRunner,
    );
    final result = await sut();

    expect(result, false);
    verify(mockRunner.stream(
      Platform.isWindows ? "dartanalyzer.bat" : "dartanalyzer",
      const [
        "--format",
        "machine",
        "lib",
        "bin",
        "test",
      ],
    ));
  });

  test("Throws error on invalid analyzer output", () async {
    when(mockRunner.stream(any, any))
        .thenAnswer((_) => Stream.fromIterable(const ["INVALID"]));

    final sut = Analyze(
      files: const [],
      logger: mockLogger,
      runner: mockRunner,
    );

    expect(() => sut(), throwsA(isA<TaskError>()));
  });

  test("Only analyzes existing directories", () async {
    final tempDir = await Directory.systemTemp.createTemp();
    final oldDir = Directory.current;
    Directory.current = tempDir;
    try {
      await Directory("lib").create();

      final sut = Analyze(
        files: const [],
        logger: mockLogger,
        runner: mockRunner,
      );
      final result = await sut();

      expect(result, false);
      verify(mockRunner.stream(
        any,
        const [
          "--format",
          "machine",
          "lib",
        ],
      ));
    } finally {
      Directory.current = oldDir;
      await tempDir.delete(recursive: true);
    }
  });

  test("Collects lints for specified files", () async {
    when(mockRunner.stream(any, any)).thenAnswer(
      (_) => Stream.fromIterable([
        "A|1|A1|${absolute("a.dart")}|10|11|12|a1",
        "A|2|A2|${absolute("a.dart")}|20|21|22|a2",
        "B|3|B3|${absolute(join("b", "b.dart"))}|30|31|32|b3",
        "C|4|C4|${absolute(join("c", "c", "c.dart"))}|40|40|40|c4",
      ]),
    );

    final sut = Analyze(
      files: [
        "a.dart",
        join("b", "b.dart"),
        join("d", "d", "d.dart"),
      ],
      logger: mockLogger,
      runner: mockRunner,
    );

    final result = await sut();
    expect(result, true);
    verify(mockLogger.log("Running linter..."));
    verify(mockLogger.log("1 - a1 - a.dart:10:11 - A1"));
    verify(mockLogger.log("2 - a2 - a.dart:20:21 - A2"));
    verify(mockLogger.log("3 - b3 - b${separator}b.dart:30:31 - B3"));
    verify(mockLogger.log("3 lint(s) found."));
    verifyNoMoreInteractions(mockLogger);
  });

  test("Succeeds if only lints of none specified files are found", () async {
    when(mockRunner.stream(any, any)).thenAnswer(
      (_) => Stream.fromIterable([
        "B|2|B2|${absolute("b.dart")}|20|21|22|b2",
      ]),
    );

    final sut = Analyze(
      files: [
        "a.dart",
      ],
      logger: mockLogger,
      runner: mockRunner,
    );

    final result = await sut();
    expect(result, false);
    verify(mockLogger.log(any)).called(2);
  });
}
