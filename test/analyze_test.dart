import 'package:dart_pre_commit/src/analyze.dart';
import 'package:dart_pre_commit/src/file_resolver.dart';
import 'package:dart_pre_commit/src/logger.dart';
import 'package:dart_pre_commit/src/program_runner.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'format_test.dart';

class MockLogger extends Mock implements Logger {}

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockFileResolver extends Mock implements FileResolver {}

void main() {
  final mockLogger = MockLogger();
  final mockRunner = MockRunner();
  final mockFileResolver = MockFileResolver();

  Analyze sut;

  setUp(() {
    reset(mockLogger);
    reset(mockRunner);
    reset(mockFileResolver);

    when(mockRunner.stream(
      any,
      any,
      failOnExit: anyNamed("failOnExit"),
    )).thenAnswer((_) => Stream.fromIterable(const []));

    when(mockFileResolver.resolve(any))
        .thenAnswer((i) async => i.positionalArguments.single as String);
    when(mockFileResolver.resolveAll(any)).thenAnswer((i) =>
        Stream.fromIterable(i.positionalArguments.single as Iterable<String>));

    sut = Analyze(
      logger: mockLogger,
      runner: mockRunner,
      fileResolver: mockFileResolver,
    );
  });

  test("Run dartanalyzer with correct arguments", () async {
    final result = await sut(const []);

    expect(result, false);
    verify(mockRunner.stream(
      "dart",
      const [
        "analyze",
      ],
      failOnExit: false,
    ));
  });

  test("Collects lints for specified files", () async {
    when(mockRunner.stream(
      any,
      any,
      failOnExit: anyNamed("failOnExit"),
    )).thenAnswer(
      (_) => Stream.fromIterable(const [
        "  A - a1 at a.dart:10:11 - (1)",
        "  A - a2 at a.dart:88:99 at at a.dart:20:21 - (2)",
        "  B - b3 at b/b.dart:30:31 - (3)",
        "  C - c4 at c/c/c.dart:40:41 - (4)",
      ]),
    );

    final result = await sut(const [
      "a.dart",
      "b/b.dart",
      "c/c/d.dart",
    ]);
    expect(result, true);
    verify(mockLogger.log("Running dart analyze..."));
    verify(mockLogger.log("  A - a1 at a.dart:10:11 - (1)"));
    verify(mockLogger.log("  A - a2 at a.dart:88:99 at at a.dart:20:21 - (2)"));
    verify(mockLogger.log("  B - b3 at b/b.dart:30:31 - (3)"));
    verify(mockLogger.log("3 issue(s) found."));
    verifyNoMoreInteractions(mockLogger);
  });

  test("Succeeds if only lints of not specified files are found", () async {
    when(mockRunner.stream(
      any,
      any,
      failOnExit: anyNamed("failOnExit"),
    )).thenAnswer(
      (_) => Stream.fromIterable([
        "  B - b3 at b/b.dart:30:31 - (3)",
      ]),
    );

    final result = await sut(["a.dart"]);
    expect(result, false);
    verify(mockLogger.log(any)).called(2);
  });
}
