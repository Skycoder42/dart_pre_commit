// ignore_for_file: unnecessary_lambdas

import 'dart:convert';
import 'dart:io';

import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/models/pull_up_dependencies/workspace.dart';
import 'package:dart_pre_commit/src/tasks/pull_up_dependencies_task.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../global_mocks.dart';

class MockFile extends Mock implements File {
  @override
  Uri get uri => Uri();
}

class MockTaskLogger extends Mock implements TaskLogger {}

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockFileResolver extends Mock implements FileResolver {}

void main() {
  group('$PullUpDependenciesConfig', () {
    testData<(Map<String, dynamic>, PullUpDependenciesConfig)>(
      'correctly converts from json',
      [
        const (<String, dynamic>{}, PullUpDependenciesConfig()),
        const (
          <String, dynamic>{
            'allowed': ['a', 'beta'],
          },
          PullUpDependenciesConfig(allowed: ['a', 'beta']),
        ),
      ],
      (fixture) {
        expect(PullUpDependenciesConfig.fromJson(fixture.$1), fixture.$2);
      },
    );
  });

  group('$PullUpDependenciesTask', () {
    final mockLogger = MockTaskLogger();
    final mockRunner = MockProgramRunner();
    final mockResolver = MockFileResolver();

    late PullUpDependenciesTask sut;

    setUp(() {
      reset(mockLogger);
      reset(mockRunner);
      reset(mockResolver);

      sut = PullUpDependenciesTask(
        logger: mockLogger,
        programRunner: mockRunner,
        fileResolver: mockResolver,
        config: const PullUpDependenciesConfig(),
      );
    });

    test('task metadata is correct', () {
      expect(sut.taskName, 'pull-up-dependencies');
      expect(sut.callForEmptyEntries, true);
    });

    testData<(String, bool)>(
      'matches only dart/pubspec.yaml files',
      const [
        ('pubspec.yaml', false),
        ('pubspec.yml', false),
        ('pubspec.lock', true),
        ('pubspec.yaml.lock', false),
        ('path/pubspec.lock', false),
      ],
      (fixture) {
        expect(
          sut.filePattern.matchAsPrefix(fixture.$1),
          fixture.$2 ? isNotNull : isNull,
        );
      },
    );

    group('check if task runs', () {
      const testWorkspace = Workspace([
        WorkspacePackage(name: 'test', path: '/test'),
      ]);

      setUp(() {
        when(
          () => mockRunner.stream(
            any(),
            any(),
            runInShell: any(named: 'runInShell'),
          ),
        ).thenStream(Stream.value(json.encode(testWorkspace)));

        when(() => mockResolver.file('pubspec.yaml')).thenAnswer((i) {
          final res = MockFile();
          // ignore: discarded_futures
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
name: pull_up
''',
          );
          return res;
        });

        when(() => mockResolver.file('/test${path.separator}pubspec.lock'))
            .thenAnswer((i) {
          final res = MockFile();
          when(() => res.path).thenReturn('/test${path.separator}pubspec.lock');
          when(() => res.existsSync()).thenReturn(true);
          // ignore: discarded_futures
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
''',
          );
          return res;
        });
      });

      test('processes packages if lockfile is ignored', () async {
        when(() => mockRunner.run(any(), any())).thenAnswer((i) async => 0);
        final result = await sut([]);

        expect(result, TaskResult.accepted);
        verify(
          () => mockRunner.run('git', const [
            'check-ignore',
            'pubspec.lock',
          ]),
        );
        verifyInOrder([
          () => mockLogger.debug('pubspec.lock is ignored'),
          () => mockLogger.debug('=> All dependencies are up to date'),
        ]);
        verifyNever(() => mockLogger.info(any()));
      });

      test('processes packages if lockfile is unstaged', () async {
        when(() => mockRunner.run(any(), any())).thenAnswer((i) async => 1);

        final result = await sut([fakeEntry('pubspec.lock')]);

        expect(result, TaskResult.accepted);
        verify(
          () => mockRunner.run('git', const [
            'check-ignore',
            'pubspec.lock',
          ]),
        );
        verifyInOrder([
          () => mockLogger
              .debug('pubspec.lock is not ignored, checking if staged'),
          () => mockLogger.debug('=> All dependencies are up to date'),
        ]);
        verifyNever(() => mockLogger.info(any()));
      });

      test('does nothing if lockfile is tracked but unstaged', () async {
        when(() => mockRunner.run(any(), any())).thenAnswer((i) async => 1);

        final result = await sut([]);

        expect(result, TaskResult.accepted);
        verify(
          () => mockRunner.run('git', const [
            'check-ignore',
            'pubspec.lock',
          ]),
        );
        verifyInOrder([
          () => mockLogger
              .debug('pubspec.lock is not ignored, checking if staged'),
          () =>
              mockLogger.debug('No staged changes for pubspec.lock, skipping'),
        ]);
        verifyNever(() => mockLogger.info(any()));
      });
    });

    group('workspace resolution', () {
      setUp(() {
        when(() => mockResolver.file('pubspec.yaml')).thenAnswer((i) {
          final res = MockFile();
          // ignore: discarded_futures
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
name: pull_up
''',
          );
          return res;
        });

        when(
          () => mockResolver
              .file(any(that: endsWith('${path.separator}pubspec.lock'))),
        ).thenAnswer((i) {
          final [String path] = i.positionalArguments;
          final res = MockFile();
          when(() => res.path).thenReturn(path);
          when(() => res.existsSync()).thenReturn(path.contains('found'));
          // ignore: discarded_futures
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
''',
          );
          return res;
        });

        // ignore: discarded_futures
        when(() => mockRunner.run(any(), any())).thenReturnAsync(0);
      });

      test('uses first workspace package with existing lockfile', () async {
        const testWorkspace = Workspace([
          WorkspacePackage(name: 'test1', path: '/test/not'),
          WorkspacePackage(name: 'test2', path: '/test/found1'),
          WorkspacePackage(name: 'test3', path: '/test/found2'),
        ]);

        when(
          () => mockRunner.stream(
            any(),
            any(),
            runInShell: any(named: 'runInShell'),
          ),
        ).thenStream(Stream.value(json.encode(testWorkspace)));

        final result = await sut([]);
        expect(result, TaskResult.accepted);
        verifyInOrder([
          () => mockRunner.stream(
                'dart',
                ['pub', 'workspace', 'list', '--json'],
                runInShell: true,
              ),
          () => mockResolver.file('/test/not${path.separator}pubspec.lock'),
          () => mockResolver.file('/test/found1${path.separator}pubspec.lock'),
          () => mockLogger.debug(
                'Detected workspace lockfile as: /test/found1${path.separator}pubspec.lock',
              ),
          () => mockResolver.file('pubspec.yaml'),
          () => mockLogger.debug('=> All dependencies are up to date'),
        ]);
        verifyNever(() => mockResolver.file(any()));
      });

      test('rejects if workspace is empty', () async {
        const testWorkspace = Workspace([]);

        when(
          () => mockRunner.stream(
            any(),
            any(),
            runInShell: any(named: 'runInShell'),
          ),
        ).thenStream(Stream.value(json.encode(testWorkspace)));

        final result = await sut([]);
        expect(result, TaskResult.rejected);
        verifyInOrder([
          () => mockRunner.stream(
                'dart',
                ['pub', 'workspace', 'list', '--json'],
                runInShell: true,
              ),
          () => mockLogger.error('Failed to find pubspec.lock in workspace'),
        ]);
        verifyNever(() => mockResolver.file(any()));
      });

      test('rejects if workspace has no lockfiles', () async {
        const testWorkspace = Workspace([
          WorkspacePackage(name: 'test1', path: '/test'),
          WorkspacePackage(name: 'test2', path: '/test/not1'),
          WorkspacePackage(name: 'test3', path: '/test/not2'),
        ]);

        when(
          () => mockRunner.stream(
            any(),
            any(),
            runInShell: any(named: 'runInShell'),
          ),
        ).thenStream(Stream.value(json.encode(testWorkspace)));

        final result = await sut([]);
        expect(result, TaskResult.rejected);
        verifyInOrder([
          () => mockRunner.stream(
                'dart',
                ['pub', 'workspace', 'list', '--json'],
                runInShell: true,
              ),
          () => mockResolver.file('/test${path.separator}pubspec.lock'),
          () => mockResolver.file('/test/not1${path.separator}pubspec.lock'),
          () => mockResolver.file('/test/not2${path.separator}pubspec.lock'),
          () => mockLogger.error('Failed to find pubspec.lock in workspace'),
        ]);
        verifyNever(() => mockResolver.file(any()));
      });
    });

    group('task operation', () {
      const testWorkspace = Workspace([
        WorkspacePackage(name: 'test', path: '/test'),
      ]);

      setUp(() {
        when(
          () => mockRunner.stream(
            any(),
            any(),
            runInShell: any(named: 'runInShell'),
          ),
        ).thenStream(Stream.value(json.encode(testWorkspace)));

        // ignore: discarded_futures
        when(() => mockRunner.run(any(), any())).thenAnswer((i) async => 0);
      });

      test('Finds updates of pulled up versions and returns true', () async {
        when(() => mockResolver.file('pubspec.yaml')).thenAnswer((i) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
name: pull_up
dependencies:
  a: ^1.0.0
  b: ^1.0.0
dev_dependencies:
  d: ^1.0.0
  e: ^1.0.0
''',
          );
          return res;
        });

        when(() => mockResolver.file('/test${path.separator}pubspec.lock'))
            .thenAnswer((i) {
          final res = MockFile();
          when(() => res.path).thenReturn('/test${path.separator}pubspec.lock');
          when(() => res.existsSync()).thenReturn(true);
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
  a:
    version: '1.0.0'
    dependency: 'direct'
  b:
    version: '1.0.1'
    dependency: 'direct'
  c:
    version: '1.1.0'
    dependency: 'direct'
  d:
    version: '1.1.0'
    dependency: 'direct'
  e:
    version: '1.0.0'
    dependency: 'direct'
  f:
    version: '1.0.1'
    dependency: 'direct'
''',
          );
          return res;
        });

        final result = await sut([]);
        expect(result, TaskResult.rejected);
        verifyInOrder([
          () => mockLogger.info('b: ^1.0.0 -> 1.0.1'),
          () => mockLogger.info('d: ^1.0.0 -> 1.1.0'),
          () => mockLogger
              .info('=> 2 dependencies can be pulled up to newer versions!'),
        ]);
        verifyNever(() => mockLogger.info(any()));
      });

      test('Prints nothing and returns true if no updates match', () async {
        when(() => mockResolver.file('pubspec.yaml')).thenAnswer((i) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
name: pull_up
dependencies:
  a: ^1.0.0
  b: 1.0.0
dev_dependencies:
  d: 1.0.0
  e: ^1.0.0
''',
          );
          return res;
        });

        when(() => mockResolver.file('/test${path.separator}pubspec.lock'))
            .thenAnswer((i) {
          final res = MockFile();
          when(() => res.path).thenReturn('/test${path.separator}pubspec.lock');
          when(() => res.existsSync()).thenReturn(true);
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
  a:
    version: '1.0.0'
    dependency: 'direct'
  b:
    version: '1.0.0'
    dependency: 'direct'
  c:
    version: '1.1.0'
    dependency: 'direct'
  d:
    version: '1.0.0'
    dependency: 'direct'
  e:
    version: '1.0.0'
    dependency: 'direct'
  f:
    version: '1.0.1'
    dependency: 'direct'
''',
          );
          return res;
        });

        final result = await sut([]);
        expect(result, TaskResult.accepted);
        verify(() => mockLogger.debug('=> All dependencies are up to date'));
        verifyNever(() => mockLogger.info(any()));
      });

      test('Does not crash if pubspec.lock is missing dependency', () async {
        when(() => mockResolver.file('pubspec.yaml')).thenAnswer((i) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
name: pull_up
dependencies:
  a: ^1.0.0
''',
          );
          return res;
        });

        when(() => mockResolver.file('/test${path.separator}pubspec.lock'))
            .thenAnswer((i) {
          final res = MockFile();
          when(() => res.path).thenReturn('/test${path.separator}pubspec.lock');
          when(() => res.existsSync()).thenReturn(true);
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
''',
          );
          return res;
        });

        final result = await sut([]);
        expect(result, TaskResult.accepted);
        verify(() => mockLogger.debug('=> All dependencies are up to date'));
        verifyNever(() => mockLogger.info(any()));
      });

      test('does not include prerelease versions', () async {
        when(() => mockResolver.file('pubspec.yaml')).thenAnswer((i) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
name: pull_up
dependencies:
  a: ^1.0.0
''',
          );
          return res;
        });

        when(() => mockResolver.file('/test${path.separator}pubspec.lock'))
            .thenAnswer((i) {
          final res = MockFile();
          when(() => res.path).thenReturn('/test${path.separator}pubspec.lock');
          when(() => res.existsSync()).thenReturn(true);
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
  a:
    version: '1.2.0-prelease.1'
    dependency: 'direct'
''',
          );
          return res;
        });

        final result = await sut([]);
        expect(result, TaskResult.accepted);
        verify(() => mockLogger.debug('=> All dependencies are up to date'));
        verifyNever(() => mockLogger.info(any()));
      });

      test('does include prerelease nullsafe versions', () async {
        when(() => mockResolver.file('pubspec.yaml')).thenAnswer((i) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
name: pull_up
dependencies:
  a: ^1.0.0
''',
          );
          return res;
        });

        when(() => mockResolver.file('/test${path.separator}pubspec.lock'))
            .thenAnswer((i) {
          final res = MockFile();
          when(() => res.path).thenReturn('/test${path.separator}pubspec.lock');
          when(() => res.existsSync()).thenReturn(true);
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
  a:
    version: '1.2.0-nullsafety.0'
    dependency: 'direct'
''',
          );
          return res;
        });

        final result = await sut([]);
        expect(result, TaskResult.rejected);
        verifyInOrder([
          () => mockLogger.info('a: ^1.0.0 -> 1.2.0-nullsafety.0'),
          () => mockLogger
              .info('=> 1 dependencies can be pulled up to newer versions!'),
        ]);
        verifyNever(() => mockLogger.info(any()));
      });

      test('does not include allowed dependencies', () async {
        when(() => mockResolver.file('pubspec.yaml')).thenAnswer((i) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
name: pull_up
dependencies:
  a: ^1.0.0
''',
          );
          return res;
        });

        when(() => mockResolver.file('/test${path.separator}pubspec.lock'))
            .thenAnswer((i) {
          final res = MockFile();
          when(() => res.path).thenReturn('/test${path.separator}pubspec.lock');
          when(() => res.existsSync()).thenReturn(true);
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
  a:
    version: '1.2.0'
    dependency: 'direct'
''',
          );
          return res;
        });

        sut = PullUpDependenciesTask(
          fileResolver: mockResolver,
          programRunner: mockRunner,
          logger: mockLogger,
          config: const PullUpDependenciesConfig(allowed: ['a']),
        );

        final result = await sut([]);
        expect(result, TaskResult.accepted);
        verify(() => mockLogger.debug('=> All dependencies are up to date'));
        verifyNever(() => mockLogger.info(any()));
      });

      test('ignores non hosted dependencies', () async {
        when(() => mockResolver.file('pubspec.yaml')).thenAnswer((i) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
name: pull_up
dependencies:
  a:
    version: ^1.0.0
    path: ./fake-a
''',
          );
          return res;
        });

        when(() => mockResolver.file('/test${path.separator}pubspec.lock'))
            .thenAnswer((i) {
          final res = MockFile();
          when(() => res.path).thenReturn('/test${path.separator}pubspec.lock');
          when(() => res.existsSync()).thenReturn(true);
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
  a:
    version: '1.2.0'
    dependency: 'direct'
''',
          );
          return res;
        });

        final result = await sut([]);
        expect(result, TaskResult.accepted);
        verify(() => mockLogger.debug('=> All dependencies are up to date'));
        verifyNever(() => mockLogger.info(any()));
      });
    });
  });
}
