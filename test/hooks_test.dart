import 'dart:io';

import 'package:dart_pre_commit/src/analyze_task.dart';
import 'package:dart_pre_commit/src/file_resolver.dart';
import 'package:dart_pre_commit/src/fix_imports_task.dart';
import 'package:dart_pre_commit/src/format_task.dart';
import 'package:dart_pre_commit/src/hooks.dart';
import 'package:dart_pre_commit/src/logger.dart';
import 'package:dart_pre_commit/src/program_runner.dart';
import 'package:dart_pre_commit/src/pull_up_dependencies_task.dart';
import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:dart_pre_commit/src/task_exception.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart'; // ignore: import_of_legacy_library_into_null_safe

import 'global_mocks.dart';
import 'hooks_test.mocks.dart';
import 'test_with_data.dart';

@GenerateMocks([
  Logger,
  FileResolver,
  ProgramRunner,
  FixImportsTask,
  FormatTask,
  AnalyzeTask,
  PullUpDependenciesTask,
])
void main() {
  final mockLogger = MockLogger();
  final mockResolver = MockFileResolver();
  final mockRunner = MockProgramRunner();
  final mockFixImports = MockFixImportsTask();
  final mockFormat = MockFormatTask();
  final mockAnalyze = MockAnalyzeTask();
  final mockPullUpDependencies = MockPullUpDependenciesTask();

  Hooks createSut({
    bool fixImports = false,
    bool format = false,
    bool analyze = false,
    bool pullUpDependencies = false,
    bool continueOnError = false,
  }) =>
      Hooks.internal(
        logger: mockLogger,
        resolver: mockResolver,
        programRunner: mockRunner,
        fixImports: fixImports ? mockFixImports : null,
        format: format ? mockFormat : null,
        analyze: analyze ? mockAnalyze : null,
        pullUpDependencies: pullUpDependencies ? mockPullUpDependencies : null,
        continueOnError: continueOnError,
      );

  setUp(() {
    reset(mockLogger);
    reset(mockResolver);
    reset(mockRunner);
    reset(mockFixImports);
    reset(mockFormat);
    reset(mockAnalyze);

    when(mockLogger.log(any)).thenReturn(null);
    when(mockLogger.logError(any)).thenReturn(null);

    when(mockResolver.file(any))
        .thenAnswer((i) => FakeFile(i.positionalArguments.first as String));
    when(mockRunner.stream(any, any))
        .thenAnswer((_) => Stream.fromIterable(const []));
    when(mockFixImports(any)).thenAnswer((_) async => false);
    when(mockFormat(any)).thenAnswer((_) async => false);
    when(mockAnalyze(any)).thenAnswer((_) async => false);
    when(mockPullUpDependencies(any)).thenAnswer((_) async => false);

    when(mockRunner.stream('git', ['rev-parse', '--show-toplevel']))
        .thenAnswer((_) => Stream.fromIterable([Directory.current.path]));
  });

  test('calls git thrice to collect changed files', () async {
    final sut = createSut();

    final result = await sut();
    expect(result, HookResult.clean);

    verify(mockRunner.stream('git', ['rev-parse', '--show-toplevel']));
    verify(mockRunner.stream('git', ['diff', '--name-only']));
    verify(mockRunner.stream('git', ['diff', '--name-only', '--cached']));
  });

  test('processes staged files', () async {
    when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
        .thenAnswer(
      (_) => Stream.fromIterable(const [
        'a.dart',
        'path/b.dart',
        'c.g.dart',
        'any.txt',
      ]),
    );
    final sut = createSut();

    final result = await sut();
    expect(result, HookResult.clean);
    verify(mockLogger.log('Scanning a.dart...'));
    verify(mockLogger.log('Scanning path${separator}b.dart...'));
    verify(mockLogger.log('Scanning c.g.dart...'));
    verify(mockLogger.log('Scanning any.txt...'));
    verifyNever(mockLogger.log(any));
  });

  test('only processes existing files', () async {
    when(mockResolver.file(any)).thenAnswer((i) => FakeFile(
          i.positionalArguments.first as String,
          exists: false,
        ));
    when(mockResolver.file('b.dart')).thenReturn(FakeFile('b.dart'));
    when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
        .thenAnswer(
      (_) => Stream.fromIterable(const [
        'a.dart',
        'b.dart',
        'c.dart',
      ]),
    );
    final sut = createSut();

    final result = await sut();
    expect(result, HookResult.clean);
    verify(mockLogger.log('Scanning b.dart...'));
    verifyNever(mockLogger.log(any));
  });

  test(
      'works if pwd is not the root subdir, only processes files in the subdir',
      () async {
    final dirName = basename(Directory.current.path);
    when(mockRunner.stream('git', [
      'rev-parse',
      '--show-toplevel',
    ])).thenAnswer(
      (_) => Stream.fromIterable([
        Directory.current.parent.path,
      ]),
    );
    when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
        .thenAnswer(
      (_) => Stream.fromIterable([
        '$dirName/a.dart',
        '$dirName/subdir/b.dart',
        'c.dart',
        'other_$dirName/d.dart',
      ]),
    );
    final sut = createSut();

    final result = await sut();
    expect(result, HookResult.clean);
    verify(mockLogger.log('Scanning a.dart...'));
    verify(mockLogger.log('Scanning subdir${separator}b.dart...'));
    verifyNever(mockLogger.log(any));
  });

  group('fixImports', () {
    setUp(() {
      when(mockFixImports.filePattern).thenReturn(RegExp('.*'));
    });

    test('gets called for matching collected files', () async {
      when(mockFixImports.filePattern).thenReturn(RegExp(r'^.*\.dart$'));
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable(const [
          'a.dart',
          'b.dart',
          'c.js',
        ]),
      );
      final sut = createSut(fixImports: true);

      final result = await sut();
      expect(result, HookResult.clean);
      final captures = verify(mockFixImports(captureAny))
          .captured
          .cast<RepoEntry>()
          .map((e) => e.file.path)
          .toList();
      expect(captures, ['a.dart', 'b.dart']);
    });

    test('gets called for all files in subdir', () async {
      final dirName = basename(Directory.current.path);
      when(mockRunner.stream('git', [
        'rev-parse',
        '--show-toplevel',
      ])).thenAnswer(
        (_) => Stream.fromIterable([
          Directory.current.parent.path,
        ]),
      );
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable([
          '$dirName/a.dart',
          '$dirName/subdir/b.dart',
          'c.dart',
          'other_$dirName/d.dart',
        ]),
      );
      final sut = createSut(fixImports: true);

      final result = await sut();
      expect(result, HookResult.clean);
      final captures = verify(mockFixImports(captureAny))
          .captured
          .cast<RepoEntry>()
          .map((e) => e.file.path)
          .toList();
      expect(captures, ['a.dart', 'subdir${separator}b.dart']);
    });

    test('returns hasChanges for staged modified files', () async {
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(mockFixImports(any)).thenAnswer((_) async => true);
      final sut = createSut(fixImports: true);

      final result = await sut();
      expect(result, HookResult.hasChanges);
      verify(mockRunner.stream('git', ['add', 'a.dart']));
    });

    test('returns hasUnstagedChanges for partially staged modified files',
        () async {
      when(mockRunner.stream('git', ['diff', '--name-only']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(mockFixImports(any)).thenAnswer((_) async => true);
      final sut = createSut(fixImports: true);

      final result = await sut();
      expect(result, HookResult.hasUnstagedChanges);
      verifyNever(mockRunner.stream('git', ['add', 'a.dart']));
    });

    testWithData<Tuple2<bool, int>>('returns error on TaskError', const [
      Tuple2(false, 1),
      Tuple2(true, 2),
    ], (fixture) async {
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable(const [
          'a.dart',
          'b.dart',
        ]),
      );
      when(mockFixImports(any))
          .thenAnswer((_) async => throw const TaskException('error'));
      final sut = createSut(
        fixImports: true,
        continueOnError: fixture.item1,
      );

      final result = await sut();
      expect(result, HookResult.error);
      verify(mockFixImports(any)).called(fixture.item2);
    });
  });

  group('format', () {
    setUp(() {
      when(mockFormat.filePattern).thenReturn(RegExp('.*'));
    });

    test('gets called for all matching collected files', () async {
      when(mockFormat.filePattern).thenReturn(RegExp(r'^.*\.dart$'));
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable(const [
          'a.dart',
          'b.dart',
          'c.js',
        ]),
      );
      final sut = createSut(format: true);

      final result = await sut();
      expect(result, HookResult.clean);
      final captures = verify(mockFormat(captureAny))
          .captured
          .cast<RepoEntry>()
          .map((e) => e.file.path)
          .toList();
      expect(captures, ['a.dart', 'b.dart']);
    });

    test('gets called for all files in subdir', () async {
      final dirName = basename(Directory.current.path);
      when(mockRunner.stream('git', [
        'rev-parse',
        '--show-toplevel',
      ])).thenAnswer(
        (_) => Stream.fromIterable([
          Directory.current.parent.path,
        ]),
      );
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable([
          '$dirName/a.dart',
          '$dirName/subdir/b.dart',
          'c.dart',
          'other_$dirName/d.dart',
        ]),
      );
      final sut = createSut(format: true);

      final result = await sut();
      expect(result, HookResult.clean);
      final captures = verify(mockFormat(captureAny))
          .captured
          .cast<RepoEntry>()
          .map((e) => e.file.path)
          .toList();
      expect(captures, ['a.dart', 'subdir${separator}b.dart']);
    });

    test('returns hasChanges for staged modified files', () async {
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(mockFormat(any)).thenAnswer((_) async => true);
      final sut = createSut(format: true);

      final result = await sut();
      expect(result, HookResult.hasChanges);
      verify(mockRunner.stream('git', ['add', 'a.dart']));
    });

    test('returns hasUnstagedChanges for partially staged modified files',
        () async {
      when(mockRunner.stream('git', ['diff', '--name-only']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(mockFormat(any)).thenAnswer((_) async => true);
      final sut = createSut(format: true);

      final result = await sut();
      expect(result, HookResult.hasUnstagedChanges);
      verifyNever(mockRunner.stream('git', ['add', 'a.dart']));
    });

    test('gets called even after fixImports finds something', () async {
      when(mockRunner.stream('git', ['diff', '--name-only']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(mockFixImports.filePattern).thenReturn(mockFormat.filePattern);
      when(mockFixImports(any)).thenAnswer((_) async => true);
      final sut = createSut(
        fixImports: true,
        format: true,
      );

      final result = await sut();
      expect(result, HookResult.hasUnstagedChanges);
      final capture = verify(mockFormat(captureAny))
          .captured
          .cast<RepoEntry>()
          .map((e) => e.file.path)
          .single;
      expect(capture, 'a.dart');
    });

    testWithData<Tuple2<bool, int>>('returns error on TaskError', const [
      Tuple2(false, 1),
      Tuple2(true, 2),
    ], (fixture) async {
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable(const [
          'a.dart',
          'b.dart',
        ]),
      );
      when(mockFormat(any))
          .thenAnswer((_) async => throw const TaskException('error'));
      final sut = createSut(
        format: true,
        continueOnError: fixture.item1,
      );

      final result = await sut();
      expect(result, HookResult.error);
      verify(mockFormat(any)).called(fixture.item2);
    });
  });

  group('analyze', () {
    setUp(() {
      when(mockAnalyze.filePattern).thenReturn(RegExp('.*'));
      when(mockAnalyze.callForEmptyEntries).thenReturn(true);
    });

    test('gets called with all matching files', () async {
      when(mockAnalyze.filePattern).thenReturn(RegExp(r'^.*\.dart$'));
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable(const [
          'a.dart',
          'b.dart',
          'c.js',
        ]),
      );
      final sut = createSut(analyze: true);

      final result = await sut();
      expect(result, HookResult.clean);
      final capture = verify(mockAnalyze(captureAny))
          .captured
          .cast<Iterable<RepoEntry>>()
          .single
          .map((e) => e.file.path);
      expect(capture, const ['a.dart', 'b.dart']);
    });

    test('gets called for all files in subdir', () async {
      final dirName = basename(Directory.current.path);
      when(mockRunner.stream('git', [
        'rev-parse',
        '--show-toplevel',
      ])).thenAnswer(
        (_) => Stream.fromIterable([
          Directory.current.parent.path,
        ]),
      );
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable([
          '$dirName/a.dart',
          '$dirName/subdir/b.dart',
          'c.dart',
          'other_$dirName/d.dart',
        ]),
      );
      final sut = createSut(analyze: true);

      final result = await sut();
      expect(result, HookResult.clean);
      final capture = verify(mockAnalyze(captureAny))
          .captured
          .cast<Iterable<RepoEntry>>()
          .single
          .map((e) => e.file.path);
      expect(capture, ['a.dart', 'subdir${separator}b.dart']);
    });

    test('does get called without any files if enabled', () async {
      final sut = createSut(analyze: true);

      final result = await sut();
      expect(result, HookResult.clean);
      verify(mockPullUpDependencies([]));
    });

    test('does not get called without any files if disabled', () async {
      when(mockAnalyze.callForEmptyEntries).thenReturn(false);
      final sut = createSut(analyze: true);

      final result = await sut();
      expect(result, HookResult.clean);
      verifyNever(mockPullUpDependencies(any));
    });

    test('returns linter if analyze find something', () async {
      when(mockAnalyze(any)).thenAnswer((_) async => true);
      final sut = createSut(analyze: true);

      final result = await sut();
      expect(result, HookResult.linter);
    });

    test('returns linter if analyze and fixImport/format find something',
        () async {
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(mockFixImports.filePattern).thenReturn(mockAnalyze.filePattern);
      when(mockFixImports(any)).thenAnswer((_) async => true);
      when(mockFormat.filePattern).thenReturn(mockAnalyze.filePattern);
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

    test('returns error on TaskError', () async {
      when(mockAnalyze(any))
          .thenAnswer((_) async => throw const TaskException('error'));
      final sut = createSut(
        analyze: true,
      );

      final result = await sut();
      expect(result, HookResult.error);
    });
  });

  group('pullUpDependencies', () {
    setUp(() {
      when(mockPullUpDependencies.filePattern).thenReturn(RegExp('.*'));
      when(mockPullUpDependencies.callForEmptyEntries).thenReturn(true);
    });

    test('gets called with matching files if enabled', () async {
      when(mockPullUpDependencies.filePattern)
          .thenReturn(RegExp(r'^.*\.dart$'));
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable(const [
          'a.dart',
          'b.dart',
          'c.js',
        ]),
      );
      final sut = createSut(pullUpDependencies: true);

      final result = await sut();
      expect(result, HookResult.clean);
      final capture = verify(mockPullUpDependencies(captureAny))
          .captured
          .cast<Iterable<RepoEntry>>()
          .single
          .map((e) => e.file.path);
      expect(capture, ['a.dart', 'b.dart']);
    });

    test('gets called for all files in subdir', () async {
      final dirName = basename(Directory.current.path);
      when(mockRunner.stream('git', [
        'rev-parse',
        '--show-toplevel',
      ])).thenAnswer(
        (_) => Stream.fromIterable([
          Directory.current.parent.path,
        ]),
      );
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable([
          '$dirName/a.dart',
          '$dirName/subdir/b.dart',
          'c.dart',
          'other_$dirName/d.dart',
        ]),
      );
      final sut = createSut(pullUpDependencies: true);

      final result = await sut();
      expect(result, HookResult.clean);
      final capture = verify(mockPullUpDependencies(captureAny))
          .captured
          .cast<Iterable<RepoEntry>>()
          .single
          .map((e) => e.file.path);
      expect(capture, ['a.dart', 'subdir${separator}b.dart']);
    });

    test('gets called without any files if enabled', () async {
      final sut = createSut(pullUpDependencies: true);

      final result = await sut();
      expect(result, HookResult.clean);
      verify(mockPullUpDependencies([]));
    });

    test('does not get called without any files if disabled', () async {
      when(mockPullUpDependencies.callForEmptyEntries).thenReturn(false);
      final sut = createSut(pullUpDependencies: true);

      final result = await sut();
      expect(result, HookResult.clean);
      verifyNever(mockPullUpDependencies(any));
    });

    test('returns canPullUp if pullUpDependencies find something', () async {
      when(mockPullUpDependencies(any)).thenAnswer((_) async => true);
      final sut = createSut(pullUpDependencies: true);

      final result = await sut();
      expect(result, HookResult.canPullUp);
    });

    test(
        'returns canPullUp if pullUpDependencies and fixImport/format find something',
        () async {
      when(mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(mockFixImports.filePattern)
          .thenReturn(mockPullUpDependencies.filePattern);
      when(mockFixImports(any)).thenAnswer((_) async => true);
      when(mockFormat.filePattern)
          .thenReturn(mockPullUpDependencies.filePattern);
      when(mockFormat(any)).thenAnswer((_) async => true);
      when(mockPullUpDependencies(any)).thenAnswer((_) async => true);
      final sut = createSut(
        fixImports: true,
        format: true,
        pullUpDependencies: true,
      );

      final result = await sut();
      expect(result, HookResult.canPullUp);
    });

    test('returns linter if analyze and pullUpDependencies find something',
        () async {
      when(mockPullUpDependencies([])).thenAnswer((_) async => true);
      when(mockAnalyze(any)).thenAnswer((_) async => true);
      final sut = createSut(
        analyze: true,
        pullUpDependencies: true,
      );

      final result = await sut();
      expect(result, HookResult.linter);
    });

    test('returns error on TaskError', () async {
      when(mockPullUpDependencies(any))
          .thenAnswer((_) async => throw const TaskException('error'));
      final sut = createSut(pullUpDependencies: true);

      final result = await sut();
      expect(result, HookResult.error);
    });
  });

  group('LintHooks.atomic', () {
    test('creates members', () async {
      final sut = await Hooks.create();
      expect(sut.logger, isNotNull);
      expect(sut.continueOnError, false);
    });

    test('honors parameters', () async {
      // ignore: prefer_const_constructors
      final myLogger = Logger.standard();
      final sut = await Hooks.create(
        fixImports: false,
        format: false,
        analyze: false,
        pullUpDependencies: true,
        continueOnError: true,
        logger: myLogger,
      );
      expect(sut.logger, myLogger);
      expect(sut.continueOnError, true);
    });
  });

  testWithData<Tuple2<HookResult, bool>>(
      'HookResult returns correct success status', const [
    Tuple2(HookResult.clean, true),
    Tuple2(HookResult.hasChanges, true),
    Tuple2(HookResult.hasUnstagedChanges, false),
    Tuple2(HookResult.canPullUp, false),
    Tuple2(HookResult.linter, false),
    Tuple2(HookResult.error, false),
  ], (fixture) {
    expect(fixture.item1.isSuccess, fixture.item2);
  });
}
