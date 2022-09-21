import 'dart:io';

import 'package:dart_pre_commit/src/hooks.dart';
import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import 'global_mocks.dart';

class MockLogger extends Mock implements Logger {}

class MockFileResolver extends Mock implements FileResolver {}

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockFileTask extends Mock with PatternTaskMixin implements FileTask {}

class MockRepoTask extends Mock with PatternTaskMixin implements RepoTask {}

void main() {
  final mockLogger = MockLogger();
  final mockResolver = MockFileResolver();
  final mockRunner = MockProgramRunner();
  final mockFileTask = MockFileTask();
  final mockRepoTask = MockRepoTask();

  Hooks createSut([
    Iterable<TaskBase> tasks = const [],
    // ignore: avoid_positional_boolean_parameters
    bool continueOnRejected = false,
  ]) =>
      Hooks(
        logger: mockLogger,
        fileResolver: mockResolver,
        programRunner: mockRunner,
        tasks: tasks.toList(),
        continueOnRejected: continueOnRejected,
      );

  setUpAll(() {
    registerFallbackValue(FakeEntry(''));
  });

  setUp(() {
    reset(mockLogger);
    reset(mockResolver);
    reset(mockRunner);
    reset(mockFileTask);
    reset(mockRepoTask);

    when(
      () => mockLogger.updateStatus(
        message: any(named: 'message'),
        status: any(named: 'status'),
        detail: any(named: 'detail'),
        clear: any(named: 'clear'),
        refresh: any(named: 'refresh'),
      ),
    ).thenReturn(null);
    when(() => mockLogger.completeStatus()).thenReturn(null);

    when(() => mockResolver.file(any()))
        .thenAnswer((i) => FakeFile(i.positionalArguments.first as String));
    when(() => mockRunner.stream(any(), any()))
        .thenAnswer((_) => Stream.fromIterable(const []));

    when(() => mockFileTask.taskName).thenReturn('file-task');
    when(() => mockFileTask.filePattern).thenReturn(RegExp('.*'));
    // ignore: discarded_futures
    when(() => mockFileTask(any()))
        .thenAnswer((_) async => TaskResult.accepted);
    when(() => mockRepoTask.taskName).thenReturn('repo-task');
    when(() => mockRepoTask.filePattern).thenReturn(RegExp('.*'));
    when(() => mockRepoTask.callForEmptyEntries).thenReturn(true);
    // ignore: discarded_futures
    when(() => mockRepoTask(any()))
        .thenAnswer((_) async => TaskResult.accepted);

    when(() => mockRunner.stream('git', ['rev-parse', '--show-toplevel']))
        .thenAnswer((_) => Stream.fromIterable([Directory.current.path]));
  });

  group('file collection', () {
    test('calls git to collect changed files', () async {
      final sut = createSut();

      final result = await sut();
      expect(result, HookResult.clean);

      verify(() => mockRunner.stream('git', ['rev-parse', '--show-toplevel']));
      verify(() => mockRunner.stream('git', ['diff', '--name-only']));
      verify(
        () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
      );
    });

    test('processes staged files', () async {
      when(() => mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable(const [
          'a.dart',
          'path/b.dart',
          'c.g.dart',
          'any().txt',
        ]),
      );
      final sut = createSut();

      final result = await sut();
      expect(result, HookResult.clean);
      verify(
        () => mockLogger.updateStatus(
          message: 'Scanning a.dart...',
          status: TaskStatus.scanning,
          refresh: any(named: 'refresh'),
        ),
      );
      verify(
        () => mockLogger.updateStatus(
          message: 'Scanning path${separator}b.dart...',
          status: TaskStatus.scanning,
          refresh: any(named: 'refresh'),
        ),
      );
      verify(
        () => mockLogger.updateStatus(
          message: 'Scanning c.g.dart...',
          status: TaskStatus.scanning,
          refresh: any(named: 'refresh'),
        ),
      );
      verify(
        () => mockLogger.updateStatus(
          message: 'Scanning any().txt...',
          status: TaskStatus.scanning,
          refresh: any(named: 'refresh'),
        ),
      );
      verifyNever(
        () => mockLogger.updateStatus(
          message: any(named: 'message'),
          status: any(named: 'status'),
          refresh: any(named: 'refresh'),
        ),
      );
    });

    test('only processes existing files', () async {
      when(() => mockResolver.file(any())).thenAnswer(
        (i) => FakeFile(
          i.positionalArguments.first as String,
          exists: false,
        ),
      );
      when(() => mockResolver.file('b.dart')).thenReturn(FakeFile('b.dart'));
      when(() => mockRunner.stream('git', ['diff', '--name-only', '--cached']))
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
      verify(
        () => mockLogger.updateStatus(
          message: 'Scanning b.dart...',
          status: TaskStatus.scanning,
          refresh: any(named: 'refresh'),
        ),
      );
      verifyNever(
        () => mockLogger.updateStatus(
          message: any(named: 'message'),
          status: any(named: 'status'),
          refresh: any(named: 'refresh'),
        ),
      );
    });

    test('only processes files in the subdir if pwd is not the root dir',
        () async {
      final dirName = basename(Directory.current.path);
      when(
        () => mockRunner.stream('git', [
          'rev-parse',
          '--show-toplevel',
        ]),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          Directory.current.parent.path,
        ]),
      );
      when(() => mockRunner.stream('git', ['diff', '--name-only', '--cached']))
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
      verify(
        () => mockLogger.updateStatus(
          message: 'Scanning a.dart...',
          status: TaskStatus.scanning,
          refresh: any(named: 'refresh'),
        ),
      );
      verify(
        () => mockLogger.updateStatus(
          message: 'Scanning subdir${separator}b.dart...',
          status: TaskStatus.scanning,
          refresh: any(named: 'refresh'),
        ),
      );
      verifyNever(
        () => mockLogger.updateStatus(
          message: any(named: 'message'),
          status: any(named: 'status'),
          refresh: any(named: 'refresh'),
        ),
      );
    });
  });

  group('file task', () {
    test('gets called for matching collected files', () async {
      when(() => mockFileTask.filePattern).thenReturn(RegExp(r'^.*\.dart$'));
      when(() => mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable(const [
          'a.dart',
          'b.dart',
          'c.js',
        ]),
      );
      final sut = createSut([mockFileTask]);

      final result = await sut();
      expect(result, HookResult.clean);
      verify(() => mockFileTask.filePattern);
      final captures = verify(() => mockFileTask(captureAny()))
          .captured
          .cast<RepoEntry>()
          .map((e) => e.file.path)
          .toList();
      expect(captures, ['a.dart', 'b.dart']);
    });

    test('returns hasChanges for staged modified files', () async {
      when(() => mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(() => mockFileTask(any()))
          .thenAnswer((_) async => TaskResult.modified);
      final sut = createSut([mockFileTask]);

      final result = await sut();
      expect(result, HookResult.hasChanges);
      verify(() => mockRunner.stream('git', ['add', 'a.dart']));
    });

    test('returns hasUnstagedChanges for partially staged modified files',
        () async {
      when(() => mockRunner.stream('git', ['diff', '--name-only']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(() => mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(() => mockFileTask(any()))
          .thenAnswer((_) async => TaskResult.modified);
      final sut = createSut([mockFileTask]);

      final result = await sut();
      expect(result, HookResult.hasUnstagedChanges);
      verifyNever(() => mockRunner.stream('git', ['add', 'a.dart']));
    });

    testData<Tuple2<bool, int>>('returns rejected on task rejected', const [
      Tuple2(false, 1),
      Tuple2(true, 2),
    ], (fixture) async {
      when(() => mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable(const [
          'a.dart',
          'b.dart',
        ]),
      );
      when(() => mockFileTask(any()))
          .thenAnswer((_) async => TaskResult.rejected);
      final sut = createSut(
        [mockFileTask],
        fixture.item1,
      );

      final result = await sut();
      expect(result, HookResult.rejected);
      verify(() => mockFileTask(any())).called(fixture.item2);
    });

    test('calls all tasks', () async {
      when(() => mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable(const ['a.dart']),
      );
      final sut = createSut([mockFileTask, mockFileTask, mockFileTask]);

      final result = await sut();
      expect(result, HookResult.clean);
      verify(() => mockFileTask(any())).called(3);
    });
  });

  group('repo task', () {
    test('gets called with all matching files', () async {
      when(() => mockRepoTask.filePattern).thenReturn(RegExp(r'^.*\.dart$'));
      when(() => mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable(const [
          'a.dart',
          'b.dart',
          'c.js',
        ]),
      );
      final sut = createSut([mockRepoTask]);

      final result = await sut();
      expect(result, HookResult.clean);
      verify(() => mockRepoTask.filePattern);
      final capture = verify(() => mockRepoTask(captureAny()))
          .captured
          .cast<Iterable<RepoEntry>>()
          .single
          .map((e) => e.file.path);
      expect(capture, const ['a.dart', 'b.dart']);
    });

    test('does get called without any() files if enabled', () async {
      final sut = createSut([mockRepoTask]);

      final result = await sut();
      expect(result, HookResult.clean);
      verify(() => mockRepoTask.callForEmptyEntries);
      verify(() => mockRepoTask([]));
    });

    test('does not get called without any() files if disabled', () async {
      when(() => mockRepoTask.callForEmptyEntries).thenReturn(false);
      final sut = createSut([mockRepoTask]);

      final result = await sut();
      expect(result, HookResult.clean);
      verify(() => mockRepoTask.callForEmptyEntries);
      verifyNever(() => mockRepoTask(any()));
    });

    test('returns hasChanges for staged modified files and adds them',
        () async {
      when(() => mockRepoTask.filePattern).thenReturn(RegExp(r'^.*\.dart$'));
      when(() => mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer(
        (_) => Stream.fromIterable(const [
          'a.dart',
          'b.txt',
        ]),
      );
      when(() => mockRepoTask(any()))
          .thenAnswer((_) async => TaskResult.modified);
      final sut = createSut([mockRepoTask]);

      final result = await sut();
      expect(result, HookResult.hasChanges);
      verify(() => mockRunner.stream('git', ['add', 'a.dart']));
      verifyNever(() => mockRunner.stream('git', ['add', 'b.txt']));
    });

    test('returns hasChanges for no files but still modified', () async {
      when(() => mockRepoTask(any()))
          .thenAnswer((_) async => TaskResult.modified);
      final sut = createSut([mockRepoTask]);

      final result = await sut();
      expect(result, HookResult.hasChanges);
    });

    test('returns hasUnstagedChanges for partially staged modified files',
        () async {
      when(() => mockRunner.stream('git', ['diff', '--name-only']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(() => mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(() => mockRepoTask(any()))
          .thenAnswer((_) async => TaskResult.modified);
      final sut = createSut([mockRepoTask]);

      final result = await sut();
      expect(result, HookResult.hasUnstagedChanges);
      verifyNever(() => mockRunner.stream('git', ['add', 'a.dart']));
    });

    testData<Tuple3<Iterable<String>?, bool, int>>(
        'returns rejected on task rejected', const [
      Tuple3(['a.dart'], false, 1),
      Tuple3(['a.dart'], true, 2),
      Tuple3(null, false, 1),
      Tuple3(null, true, 2),
    ], (fixture) async {
      if (fixture.item1 != null) {
        when(
          () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
        ).thenAnswer(
          (_) => Stream.fromIterable(fixture.item1!),
        );
      }
      when(() => mockRepoTask(any()))
          .thenAnswer((_) async => TaskResult.rejected);
      final sut = createSut(
        [mockRepoTask, mockRepoTask],
        fixture.item2,
      );

      final result = await sut();
      expect(result, HookResult.rejected);
      verify(() => mockRepoTask(any())).called(fixture.item3);
    });
  });

  testData<Tuple3<TaskResult, TaskResult, HookResult>>(
    'mixed tasks report correct result',
    const [
      Tuple3(TaskResult.accepted, TaskResult.accepted, HookResult.clean),
      Tuple3(TaskResult.accepted, TaskResult.modified, HookResult.hasChanges),
      Tuple3(TaskResult.modified, TaskResult.accepted, HookResult.hasChanges),
      Tuple3(TaskResult.modified, TaskResult.rejected, HookResult.rejected),
      Tuple3(TaskResult.rejected, TaskResult.modified, HookResult.rejected),
    ],
    (fixture) async {
      when(() => mockRunner.stream('git', ['diff', '--name-only', '--cached']))
          .thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(() => mockFileTask(any())).thenAnswer((i) async => fixture.item1);
      when(() => mockRepoTask(any())).thenAnswer((i) async => fixture.item2);
      final sut = createSut([mockRepoTask, mockFileTask], true);

      final result = await sut();
      expect(result, fixture.item3);
      verify(() => mockFileTask(any()));
      verify(() => mockRepoTask(any()));
    },
  );

  testData<Tuple2<HookResult, bool>>(
      'HookResult returns correct success status', const [
    Tuple2(HookResult.clean, true),
    Tuple2(HookResult.hasChanges, true),
    Tuple2(HookResult.hasUnstagedChanges, false),
    Tuple2(HookResult.rejected, false),
  ], (fixture) {
    expect(fixture.item1.isSuccess, fixture.item2);
  });
}
