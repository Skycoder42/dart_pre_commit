// ignore_for_file: unnecessary_lambdas

import 'dart:io';

import 'package:dart_pre_commit/src/config/config_loader.dart';
import 'package:dart_pre_commit/src/hooks.dart';
import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/provider/task_loader.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

import 'global_mocks.dart';

class MockLogger extends Mock implements Logger {}

class MockFileResolver extends Mock implements FileResolver {}

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockConfigLoader extends Mock implements ConfigLoader {}

class MockTaskLoader extends Mock implements TaskLoader {}

class MockFileTask extends Mock with PatternTaskMixin implements FileTask {}

class MockRepoTask extends Mock with PatternTaskMixin implements RepoTask {}

void main() {
  final mockLogger = MockLogger();
  final mockResolver = MockFileResolver();
  final mockRunner = MockProgramRunner();
  final mockConfigLoader = MockConfigLoader();
  final mockTaskLoader = MockTaskLoader();
  final mockFileTask = MockFileTask();
  final mockRepoTask = MockRepoTask();

  Hooks createSut({bool continueOnRejected = false, String? configFile}) =>
      Hooks(
        fileResolver: mockResolver,
        programRunner: mockRunner,
        taskLoader: mockTaskLoader,
        configLoader: mockConfigLoader,
        logger: mockLogger,
        config: HooksConfig(
          continueOnRejected: continueOnRejected,
          configFile: configFile,
        ),
      );

  setUpAll(() {
    registerFallbackValue(fakeEntry(''));
  });

  setUp(() async {
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

    when(
      () => mockResolver.file(any()),
    ).thenAnswer((i) => FakeFile(i.positionalArguments.first as String));
    when(
      () => mockRunner.stream(any(), any()),
    ).thenAnswer((_) => Stream.fromIterable(const []));

    when(() => mockFileTask.taskName).thenReturn('file-task');
    when(() => mockFileTask.filePattern).thenReturn(RegExp('.*'));
    // ignore: discarded_futures
    when(
      () => mockFileTask(any()),
    ).thenAnswer((_) async => TaskResult.accepted);
    when(() => mockRepoTask.taskName).thenReturn('repo-task');
    when(() => mockRepoTask.filePattern).thenReturn(RegExp('.*'));
    when(() => mockRepoTask.callForEmptyEntries).thenReturn(true);
    // ignore: discarded_futures
    when(
      () => mockRepoTask(any()),
    ).thenAnswer((_) async => TaskResult.accepted);

    when(
      () => mockRunner.stream('git', ['rev-parse', '--show-toplevel']),
    ).thenAnswer((_) => Stream.fromIterable([Directory.current.path]));

    when(() => mockConfigLoader.loadGlobalConfig(any())).thenReturnAsync(true);
    when(() => mockConfigLoader.loadExcludePatterns()).thenReturn(const []);
  });

  group('config', () {
    test('skips all tests if config is disabled', () async {
      when(() => mockConfigLoader.loadGlobalConfig()).thenReturnAsync(false);
      when(
        () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
      ).thenStream(Stream.fromIterable(const ['a.dart']));

      final sut = createSut();

      final result = await sut();
      expect(result, HookResult.clean);

      verifyInOrder([
        () => mockConfigLoader.loadGlobalConfig(),
        () => mockLogger.info(any(that: contains('disabled'))),
      ]);
    });

    test('uses custom config if config path is given', () async {
      const testConfigFilePath = '/custom/config.yaml';
      final testConfigFile = FakeFile(testConfigFilePath);
      when(() => mockResolver.file(any())).thenReturn(testConfigFile);
      when(() => mockTaskLoader.loadTasks()).thenReturn([]);

      final sut = createSut(configFile: testConfigFilePath);

      final result = await sut();
      expect(result, HookResult.clean);

      verifyInOrder([
        () => mockResolver.file(testConfigFilePath),
        () => mockConfigLoader.loadGlobalConfig(testConfigFile),
      ]);
    });
  });

  group('file collection', () {
    test('calls git to collect changed files', () async {
      when(() => mockTaskLoader.loadTasks()).thenReturn([]);

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
      when(
        () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          'a.dart',
          'path/b.dart',
          'c.g.dart',
          'any().txt',
        ]),
      );
      when(() => mockTaskLoader.loadTasks()).thenReturn([]);

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
        (i) => FakeFile(i.positionalArguments.first as String, exists: false),
      );
      when(() => mockResolver.file('b.dart')).thenReturn(FakeFile('b.dart'));
      when(
        () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
      ).thenAnswer(
        (_) => Stream.fromIterable(const ['a.dart', 'b.dart', 'c.dart']),
      );
      when(() => mockTaskLoader.loadTasks()).thenReturn([]);

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

    test(
      'only processes files in the subdir if pwd is not the root dir',
      () async {
        final dirName = basename(Directory.current.path);
        when(
          () => mockRunner.stream('git', ['rev-parse', '--show-toplevel']),
        ).thenAnswer(
          (_) => Stream.fromIterable([Directory.current.parent.path]),
        );
        when(
          () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            '$dirName/a.dart',
            '$dirName/subdir/b.dart',
            'c.dart',
            'other_$dirName/d.dart',
          ]),
        );
        when(() => mockTaskLoader.loadTasks()).thenReturn([]);

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
      },
    );

    test('skips excluded files', () async {
      when(
        () => mockConfigLoader.loadExcludePatterns(),
      ).thenReturn([RegExp(r'b\.dart'), RegExp(r'.*c\.dart$')]);
      when(
        () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
      ).thenAnswer(
        (_) => Stream.fromIterable(const ['a.dart', 'b.dart', 'sub/c.dart']),
      );
      when(() => mockTaskLoader.loadTasks()).thenReturn([]);

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
      when(
        () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
      ).thenAnswer(
        (_) => Stream.fromIterable(const ['a.dart', 'b.dart', 'c.js']),
      );
      when(() => mockTaskLoader.loadTasks()).thenReturn([mockFileTask]);
      final sut = createSut();

      final result = await sut();
      expect(result, HookResult.clean);
      verify(() => mockTaskLoader.loadTasks());
      verify(() => mockFileTask.filePattern);
      final captures =
          verify(
            () => mockFileTask(captureAny()),
          ).captured.cast<RepoEntry>().map((e) => e.file.path).toList();
      expect(captures, ['a.dart', 'b.dart']);
    });

    test('returns hasChanges for staged modified files', () async {
      when(
        () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
      ).thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(
        () => mockFileTask(any()),
      ).thenAnswer((_) async => TaskResult.modified);
      when(() => mockTaskLoader.loadTasks()).thenReturn([mockFileTask]);
      final sut = createSut();

      final result = await sut();
      expect(result, HookResult.hasChanges);
      verify(() => mockRunner.stream('git', ['add', 'a.dart']));
    });

    test(
      'returns hasUnstagedChanges for partially staged modified files',
      () async {
        when(
          () => mockRunner.stream('git', ['diff', '--name-only']),
        ).thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
        when(
          () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
        ).thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
        when(
          () => mockFileTask(any()),
        ).thenAnswer((_) async => TaskResult.modified);
        when(() => mockTaskLoader.loadTasks()).thenReturn([mockFileTask]);
        final sut = createSut();

        final result = await sut();
        expect(result, HookResult.hasUnstagedChanges);
        verifyNever(() => mockRunner.stream('git', ['add', 'a.dart']));
      },
    );

    testData<(bool, int)>(
      'returns rejected on task rejected',
      const [(false, 1), (true, 2)],
      (fixture) async {
        when(
          () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
        ).thenAnswer((_) => Stream.fromIterable(const ['a.dart', 'b.dart']));
        when(
          () => mockFileTask(any()),
        ).thenAnswer((_) async => TaskResult.rejected);
        when(() => mockTaskLoader.loadTasks()).thenReturn([mockFileTask]);
        final sut = createSut(continueOnRejected: fixture.$1);

        final result = await sut();
        expect(result, HookResult.rejected);
        verify(() => mockFileTask(any())).called(fixture.$2);
      },
    );

    test('calls all tasks', () async {
      when(
        () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
      ).thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
      when(
        () => mockTaskLoader.loadTasks(),
      ).thenReturn([mockFileTask, mockFileTask, mockFileTask]);
      final sut = createSut();

      final result = await sut();
      expect(result, HookResult.clean);
      verify(() => mockFileTask(any())).called(3);
    });
  });

  group('repo task', () {
    test('gets called with all matching files', () async {
      when(() => mockRepoTask.filePattern).thenReturn(RegExp(r'^.*\.dart$'));
      when(
        () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
      ).thenAnswer(
        (_) => Stream.fromIterable(const ['a.dart', 'b.dart', 'c.js']),
      );
      when(() => mockTaskLoader.loadTasks()).thenReturn([mockRepoTask]);
      final sut = createSut();

      final result = await sut();
      expect(result, HookResult.clean);
      verify(() => mockTaskLoader.loadTasks());
      verify(() => mockRepoTask.filePattern);
      final capture = verify(
        () => mockRepoTask(captureAny()),
      ).captured.cast<Iterable<RepoEntry>>().single.map((e) => e.file.path);
      expect(capture, const ['a.dart', 'b.dart']);
    });

    test('does get called without any matching files if enabled', () async {
      when(() => mockRepoTask.filePattern).thenReturn(RegExp(r'^.*\.dart$'));
      when(
        () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
      ).thenAnswer((_) => Stream.fromIterable(const ['a.js']));
      when(() => mockTaskLoader.loadTasks()).thenReturn([mockRepoTask]);
      final sut = createSut();

      final result = await sut();
      expect(result, HookResult.clean);
      verify(() => mockRepoTask.callForEmptyEntries);
      verify(() => mockRepoTask([]));
    });

    test('does not get called without any() files if disabled', () async {
      when(() => mockRepoTask.callForEmptyEntries).thenReturn(false);
      when(() => mockRepoTask.filePattern).thenReturn(RegExp(r'^.*\.dart$'));
      when(
        () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
      ).thenAnswer((_) => Stream.fromIterable(const ['a.js']));
      when(() => mockTaskLoader.loadTasks()).thenReturn([mockRepoTask]);
      final sut = createSut();

      final result = await sut();
      expect(result, HookResult.clean);
      verify(() => mockRepoTask.callForEmptyEntries);
      verifyNever(() => mockRepoTask(any()));
    });

    test(
      'returns hasChanges for staged modified files and adds them',
      () async {
        when(() => mockRepoTask.filePattern).thenReturn(RegExp(r'^.*\.dart$'));
        when(
          () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
        ).thenAnswer((_) => Stream.fromIterable(const ['a.dart', 'b.txt']));
        when(
          () => mockRepoTask(any()),
        ).thenAnswer((_) async => TaskResult.modified);
        when(() => mockTaskLoader.loadTasks()).thenReturn([mockRepoTask]);
        final sut = createSut();

        final result = await sut();
        expect(result, HookResult.hasChanges);
        verify(() => mockRunner.stream('git', ['add', 'a.dart']));
        verifyNever(() => mockRunner.stream('git', ['add', 'b.txt']));
      },
    );

    test('returns hasChanges for no files but still modified', () async {
      when(() => mockRepoTask.filePattern).thenReturn(RegExp(r'^.*\.dart$'));
      when(
        () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
      ).thenAnswer((_) => Stream.fromIterable(const ['b.txt']));
      when(
        () => mockRepoTask(any()),
      ).thenAnswer((_) async => TaskResult.modified);
      when(() => mockTaskLoader.loadTasks()).thenReturn([mockRepoTask]);
      final sut = createSut();

      final result = await sut();
      expect(result, HookResult.hasChanges);
    });

    test(
      'returns hasUnstagedChanges for partially staged modified files',
      () async {
        when(
          () => mockRunner.stream('git', ['diff', '--name-only']),
        ).thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
        when(
          () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
        ).thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
        when(
          () => mockRepoTask(any()),
        ).thenAnswer((_) async => TaskResult.modified);
        when(() => mockTaskLoader.loadTasks()).thenReturn([mockRepoTask]);
        final sut = createSut();

        final result = await sut();
        expect(result, HookResult.hasUnstagedChanges);
        verifyNever(() => mockRunner.stream('git', ['add', 'a.dart']));
      },
    );

    testData<(Iterable<String>?, bool, int)>(
      'returns rejected on task rejected',
      const [
        (['a.dart'], false, 1),
        (['a.dart'], true, 2),
        (null, false, 1),
        (null, true, 2),
      ],
      (fixture) async {
        if (fixture.$1 != null) {
          when(
            () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
          ).thenAnswer((_) => Stream.fromIterable(fixture.$1!));
        } else {
          when(
            () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
          ).thenAnswer((_) => Stream.value('other.txt'));
        }
        when(
          () => mockRepoTask(any()),
        ).thenAnswer((_) async => TaskResult.rejected);
        when(
          () => mockTaskLoader.loadTasks(),
        ).thenReturn([mockRepoTask, mockRepoTask]);
        final sut = createSut(continueOnRejected: fixture.$2);

        final result = await sut();
        expect(result, HookResult.rejected);
        verify(() => mockRepoTask(any())).called(fixture.$3);
      },
    );
  });

  group('mixed tasks', () {
    testData<(TaskResult, TaskResult, HookResult)>(
      'reports correct results',
      const [
        (TaskResult.accepted, TaskResult.accepted, HookResult.clean),
        (TaskResult.accepted, TaskResult.modified, HookResult.hasChanges),
        (TaskResult.modified, TaskResult.accepted, HookResult.hasChanges),
        (TaskResult.modified, TaskResult.rejected, HookResult.rejected),
        (TaskResult.rejected, TaskResult.modified, HookResult.rejected),
      ],
      (fixture) async {
        when(
          () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
        ).thenAnswer((_) => Stream.fromIterable(const ['a.dart']));
        when(() => mockFileTask(any())).thenAnswer((i) async => fixture.$1);
        when(() => mockRepoTask(any())).thenAnswer((i) async => fixture.$2);
        when(
          () => mockTaskLoader.loadTasks(),
        ).thenReturn([mockRepoTask, mockFileTask]);
        final sut = createSut(continueOnRejected: true);

        final result = await sut();
        expect(result, fixture.$3);
        verify(() => mockFileTask(any()));
        verify(() => mockRepoTask(any()));
      },
    );

    test(
      'returns clean and does nothing if no files have been staged',
      () async {
        when(
          () => mockRunner.stream('git', ['diff', '--name-only', '--cached']),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => mockTaskLoader.loadTasks(),
        ).thenReturn([mockRepoTask, mockFileTask]);

        final sut = createSut(continueOnRejected: true);

        final result = await sut();
        expect(result, HookResult.clean);
        verifyZeroInteractions(mockRepoTask);
        verifyZeroInteractions(mockFileTask);
      },
    );
  });

  testData<(HookResult, bool, int)>(
    'HookResult returns correct success and exit status',
    const [
      (HookResult.clean, true, 0),
      (HookResult.hasChanges, true, 1),
      (HookResult.hasUnstagedChanges, false, 2),
      (HookResult.rejected, false, 3),
    ],
    (fixture) {
      expect(fixture.$1.isSuccess, fixture.$2);
      expect(fixture.$1.exitCode, fixture.$3);
    },
  );
}
