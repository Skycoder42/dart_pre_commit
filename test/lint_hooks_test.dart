import 'package:dart_lint_hooks/dart_lint_hooks.dart';
import 'package:dart_lint_hooks/src/analyze.dart';
import 'package:dart_lint_hooks/src/fix_imports.dart';
import 'package:dart_lint_hooks/src/format.dart';
import 'package:dart_lint_hooks/src/logger.dart';
import 'package:dart_lint_hooks/src/program_runner.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockFixImports extends Mock implements FixImports {}

class MockFormat extends Mock implements Format {}

class MockAnalyze extends Mock implements Analyze {}

void main() {
  final mockLogger = MockLogger();
  final mockRunner = MockProgramRunner();
  final mockFixImports = MockFixImports();
  final mockFormat = MockFormat();
  final mockAnalyze = MockAnalyze();

  LintHooks createSut({
    bool fixImports = false,
    bool format = false,
    bool analyze = false,
    bool continueOnError = false,
  }) =>
      LintHooks(
        logger: mockLogger,
        runner: mockRunner,
        fixImports: fixImports ? mockFixImports : null,
        format: format ? mockFormat : null,
        analyze: analyze ? mockAnalyze : null,
        continueOnError: continueOnError,
      );

  setUp(() {
    reset(mockLogger);
    reset(mockRunner);
    reset(mockFixImports);
    reset(mockFormat);
    reset(mockAnalyze);

    when(mockRunner.stream(any, any))
        .thenAnswer((_) => Stream.fromIterable(const []));
  });

  test("calls git twice to collect changed files", () async {
    final sut = createSut();

    final result = await sut();
    expect(result, LintResult.clean);

    verify(mockRunner.stream("git", ["diff", "--name-only"]));
    verify(mockRunner.stream("git", ["diff", "--name-only", "--cached"]));
  });

  test("only processes staged dart files", () async {
    when(mockRunner.stream(any, any))
        .thenAnswer((_) => Stream.fromIterable(const [
              "a.dart",
              "b.js",
              "c.g.dart",
            ]));
    final sut = createSut();

    final result = await sut();
    expect(result, LintResult.clean);
    verify(mockLogger.log("Scanning a.dart..."));
    verify(mockLogger.log("Scanning c.g.dart..."));
    verifyNoMoreInteractions(mockLogger);
  });
}
