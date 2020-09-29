import 'dart:io';

import 'package:dart_pre_commit/src/analyze.dart';
import 'package:dart_pre_commit/src/fix_imports.dart';
import 'package:dart_pre_commit/src/format.dart';
import 'package:dart_pre_commit/src/hooks.dart';
import 'package:dart_pre_commit/src/logger.dart';
import 'package:dart_pre_commit/src/program_runner.dart';
import 'package:dart_pre_commit/src/task_error.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import 'test_with_data.dart';

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

  Hooks createSut({
    bool fixImports = false,
    bool format = false,
    bool analyze = false,
    bool continueOnError = false,
  }) =>
      Hooks.internal(
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
    when(mockFixImports(any)).thenAnswer((_) async => false);
    when(mockFormat(any)).thenAnswer((_) async => false);
    when(mockAnalyze(any)).thenAnswer((_) async => false);
  });

  test("calls git twice to collect changed files", () async {
    final sut = createSut();

    final result = await sut();
    expect(result, HookResult.clean);

    verify(mockRunner.stream("git", ["diff", "--name-only"]));
    verify(mockRunner.stream("git", ["diff", "--name-only", "--cached"]));
  });

  test("only processes staged dart files", () async {
    when(mockRunner.stream(any, any)).thenAnswer(
      (_) => Stream.fromIterable(const [
        "a.dart",
        "b.js",
        "c.g.dart",
      ]),
    );
    final sut = createSut();

    final result = await sut();
    expect(result, HookResult.clean);
    verify(mockLogger.log("Scanning a.dart..."));
    verify(mockLogger.log("Scanning c.g.dart..."));
    verifyNoMoreInteractions(mockLogger);
  });

  group("fixImports", () {
    test("gets called for all collected files", () async {
      when(mockRunner.stream(any, any)).thenAnswer(
        (_) => Stream.fromIterable(const [
          "a.dart",
          "b.dart",
        ]),
      );
      final sut = createSut(fixImports: true);

      final result = await sut();
      expect(result, HookResult.clean);
      final captures = verify(mockFixImports(captureAny))
          .captured
          .map((dynamic c) => (c as File).path)
          .toList();
      expect(captures, ["a.dart", "b.dart"]);
    });

    test("returns hasChanges for staged modified files", () async {
      when(mockRunner.stream("git", ["diff", "--name-only", "--cached"]))
          .thenAnswer((_) => Stream.fromIterable(const ["a.dart"]));
      when(mockFixImports(any)).thenAnswer((_) async => true);
      final sut = createSut(fixImports: true);

      final result = await sut();
      expect(result, HookResult.hasChanges);
      verify(mockRunner.stream("git", ["add", "a.dart"]));
    });

    test("returns hasUnstagedChanges for partially staged modified files",
        () async {
      when(mockRunner.stream(any, any))
          .thenAnswer((_) => Stream.fromIterable(const ["a.dart"]));
      when(mockFixImports(any)).thenAnswer((_) async => true);
      final sut = createSut(fixImports: true);

      final result = await sut();
      expect(result, HookResult.hasUnstagedChanges);
      verifyNever(mockRunner.stream("git", ["add", "a.dart"]));
    });

    testWithData<Tuple2<bool, int>>("returns error on TaskError", const [
      Tuple2(false, 1),
      Tuple2(true, 2),
    ], (fixture) async {
      when(mockRunner.stream(any, any)).thenAnswer(
        (_) => Stream.fromIterable(const [
          "a.dart",
          "b.dart",
        ]),
      );
      when(mockFixImports(any))
          .thenAnswer((_) async => throw const TaskError("error"));
      final sut = createSut(
        fixImports: true,
        continueOnError: fixture.item1,
      );

      final result = await sut();
      expect(result, HookResult.error);
      verify(mockFixImports(any)).called(fixture.item2);
    });
  });

  group("format", () {
    test("gets called for all collected files", () async {
      when(mockRunner.stream(any, any)).thenAnswer(
        (_) => Stream.fromIterable(const [
          "a.dart",
          "b.dart",
        ]),
      );
      final sut = createSut(format: true);

      final result = await sut();
      expect(result, HookResult.clean);
      final captures = verify(mockFormat(captureAny))
          .captured
          .map((dynamic c) => (c as File).path)
          .toList();
      expect(captures, ["a.dart", "b.dart"]);
    });

    test("returns hasChanges for staged modified files", () async {
      when(mockRunner.stream("git", ["diff", "--name-only", "--cached"]))
          .thenAnswer((_) => Stream.fromIterable(const ["a.dart"]));
      when(mockFormat(any)).thenAnswer((_) async => true);
      final sut = createSut(format: true);

      final result = await sut();
      expect(result, HookResult.hasChanges);
      verify(mockRunner.stream("git", ["add", "a.dart"]));
    });

    test("returns hasUnstagedChanges for partially staged modified files",
        () async {
      when(mockRunner.stream(any, any))
          .thenAnswer((_) => Stream.fromIterable(const ["a.dart"]));
      when(mockFormat(any)).thenAnswer((_) async => true);
      final sut = createSut(format: true);

      final result = await sut();
      expect(result, HookResult.hasUnstagedChanges);
      verifyNever(mockRunner.stream("git", ["add", "a.dart"]));
    });

    test("gets called even after fixImports finds something", () async {
      when(mockRunner.stream(any, any))
          .thenAnswer((_) => Stream.fromIterable(const ["a.dart"]));
      when(mockFixImports(any)).thenAnswer((_) async => true);
      final sut = createSut(
        fixImports: true,
        format: true,
      );

      final result = await sut();
      expect(result, HookResult.hasUnstagedChanges);
      final capture = verify(mockFormat(captureAny))
          .captured
          .map((dynamic c) => (c as File).path)
          .single;
      expect(capture, "a.dart");
    });

    testWithData<Tuple2<bool, int>>("returns error on TaskError", const [
      Tuple2(false, 1),
      Tuple2(true, 2),
    ], (fixture) async {
      when(mockRunner.stream(any, any)).thenAnswer(
        (_) => Stream.fromIterable(const [
          "a.dart",
          "b.dart",
        ]),
      );
      when(mockFormat(any))
          .thenAnswer((_) async => throw const TaskError("error"));
      final sut = createSut(
        format: true,
        continueOnError: fixture.item1,
      );

      final result = await sut();
      expect(result, HookResult.error);
      verify(mockFormat(any)).called(fixture.item2);
    });
  });

  group("analyze", () {
    test("gets called with all files", () async {
      when(mockRunner.stream(any, any)).thenAnswer(
        (_) => Stream.fromIterable(const [
          "a.dart",
          "b.dart",
        ]),
      );
      final sut = createSut(analyze: true);

      final result = await sut();
      expect(result, HookResult.clean);
      final capture = verify(mockAnalyze(captureAny))
          .captured
          .cast<Iterable<String>>()
          .single
          .toList();
      expect(capture, const ["a.dart", "b.dart"]);
    });

    test("returns linter if analyze find something", () async {
      when(mockAnalyze(any)).thenAnswer((_) async => true);
      final sut = createSut(analyze: true);

      final result = await sut();
      expect(result, HookResult.linter);
    });

    test("returns linter if analyze and fixImport/format find something",
        () async {
      when(mockRunner.stream(any, any))
          .thenAnswer((_) => Stream.fromIterable(const ["a.dart"]));
      when(mockFixImports(any)).thenAnswer((_) async => true);
      when(mockFormat(any)).thenAnswer((_) async => true);
      when(mockAnalyze(any)).thenAnswer((_) async => true);
      final sut = createSut(
        fixImports: true,
        format: true,
        analyze: true,
      );

      final result = await sut();
      expect(result, HookResult.linter);
    });

    test("returns error on TaskError", () async {
      when(mockAnalyze(any))
          .thenAnswer((_) async => throw const TaskError("error"));
      final sut = createSut(
        analyze: true,
      );

      final result = await sut();
      expect(result, HookResult.error);
    });
  });

  group("LintHooks.atomic", () {
    test("creates members", () async {
      final sut = await Hooks.create();
      expect(sut.logger, isNotNull);
      expect(sut.runner, isNotNull);
      expect(sut.fixImports, isNotNull);
      expect(sut.format, isNotNull);
      expect(sut.analyze, isNotNull);
      expect(sut.continueOnError, false);

      expect(sut.fixImports.libDir.path, "lib");
      expect(sut.fixImports.packageName, "dart_pre_commit");

      expect(sut.format.runner, sut.runner);

      expect(sut.analyze.logger, sut.logger);
      expect(sut.analyze.runner, sut.runner);
    });

    test("honors parameters", () async {
      final sut = await Hooks.create(
        fixImports: false,
        format: false,
        analyze: false,
        continueOnError: true,
        logger: null,
      );
      expect(sut.logger, isNull);
      expect(sut.runner, isNotNull);
      expect(sut.fixImports, isNull);
      expect(sut.format, isNull);
      expect(sut.analyze, isNull);
      expect(sut.continueOnError, true);
    });
  });

  testWithData<Tuple2<HookResult, bool>>(
      "HookResult returns correct success status", const [
    Tuple2(HookResult.clean, true),
    Tuple2(HookResult.hasChanges, true),
    Tuple2(HookResult.hasUnstagedChanges, false),
    Tuple2(HookResult.linter, false),
    Tuple2(HookResult.error, false),
  ], (fixture) {
    expect(fixture.item1.isSuccess, fixture.item2);
  });
}
