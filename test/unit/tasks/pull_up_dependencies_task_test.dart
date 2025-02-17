// ignore_for_file: unnecessary_lambdas

import 'dart:io';

import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/pull_up_dependencies_task.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/lockfile_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../global_mocks.dart';

class MockFile extends Mock implements File {
  @override
  Uri get uri => Uri();
}

class MockTaskLogger extends Mock implements TaskLogger {}

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockFileResolver extends Mock implements FileResolver {}

class MockLockfileResolver extends Mock implements LockfileResolver {}

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
    final mockLockfileResolver = MockLockfileResolver();

    late PullUpDependenciesTask sut;

    setUp(() {
      reset(mockLogger);
      reset(mockRunner);
      reset(mockResolver);
      reset(mockLockfileResolver);

      sut = PullUpDependenciesTask(
        logger: mockLogger,
        programRunner: mockRunner,
        fileResolver: mockResolver,
        lockfileResolver: mockLockfileResolver,
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
      setUp(() async {
        when(() => mockResolver.file('pubspec.yaml')).thenAnswer((i) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
name: pull_up
''',
          );
          return res;
        });

        when(() => mockLockfileResolver.findWorkspaceLockfile()).thenAnswer((
          i,
        ) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
''',
          );
          return Future.value(res);
        });
      });

      test('processes packages if lockfile is ignored', () async {
        when(() => mockRunner.run(any(), any())).thenAnswer((i) async => 0);
        final result = await sut([]);

        expect(result, TaskResult.accepted);
        verify(
          () => mockRunner.run('git', const ['check-ignore', 'pubspec.lock']),
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
          () => mockRunner.run('git', const ['check-ignore', 'pubspec.lock']),
        );
        verifyInOrder([
          () => mockLogger.debug(
            'pubspec.lock is not ignored, checking if staged',
          ),
          () => mockLogger.debug('=> All dependencies are up to date'),
        ]);
        verifyNever(() => mockLogger.info(any()));
      });

      test('does nothing if lockfile is tracked but unstaged', () async {
        when(() => mockRunner.run(any(), any())).thenAnswer((i) async => 1);

        final result = await sut([]);

        expect(result, TaskResult.accepted);
        verify(
          () => mockRunner.run('git', const ['check-ignore', 'pubspec.lock']),
        );
        verifyInOrder([
          () => mockLogger.debug(
            'pubspec.lock is not ignored, checking if staged',
          ),
          () =>
              mockLogger.debug('No staged changes for pubspec.lock, skipping'),
        ]);
        verifyNever(() => mockLogger.info(any()));
      });
    });

    group('task operation', () {
      setUp(() async {
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

        when(() => mockLockfileResolver.findWorkspaceLockfile()).thenAnswer((
          i,
        ) {
          final res = MockFile();
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
          return Future.value(res);
        });

        final result = await sut([]);
        expect(result, TaskResult.rejected);
        verifyInOrder([
          () => mockLogger.info('b: ^1.0.0 -> 1.0.1'),
          () => mockLogger.info('d: ^1.0.0 -> 1.1.0'),
          () => mockLogger.info(
            '=> 2 dependencies can be pulled up to newer versions!',
          ),
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

        when(() => mockLockfileResolver.findWorkspaceLockfile()).thenAnswer((
          i,
        ) {
          final res = MockFile();
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
          return Future.value(res);
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

        when(() => mockLockfileResolver.findWorkspaceLockfile()).thenAnswer((
          i,
        ) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
''',
          );
          return Future.value(res);
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

        when(() => mockLockfileResolver.findWorkspaceLockfile()).thenAnswer((
          i,
        ) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
  a:
    version: '1.2.0-prelease.1'
    dependency: 'direct'
''',
          );
          return Future.value(res);
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

        when(() => mockLockfileResolver.findWorkspaceLockfile()).thenAnswer((
          i,
        ) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
  a:
    version: '1.2.0-nullsafety.0'
    dependency: 'direct'
''',
          );
          return Future.value(res);
        });

        final result = await sut([]);
        expect(result, TaskResult.rejected);
        verifyInOrder([
          () => mockLogger.info('a: ^1.0.0 -> 1.2.0-nullsafety.0'),
          () => mockLogger.info(
            '=> 1 dependencies can be pulled up to newer versions!',
          ),
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

        when(() => mockLockfileResolver.findWorkspaceLockfile()).thenAnswer((
          i,
        ) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
  a:
    version: '1.2.0'
    dependency: 'direct'
''',
          );
          return Future.value(res);
        });

        sut = PullUpDependenciesTask(
          fileResolver: mockResolver,
          programRunner: mockRunner,
          lockfileResolver: mockLockfileResolver,
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

        when(() => mockLockfileResolver.findWorkspaceLockfile()).thenAnswer((
          i,
        ) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
packages:
  a:
    version: '1.2.0'
    dependency: 'direct'
''',
          );
          return Future.value(res);
        });

        final result = await sut([]);
        expect(result, TaskResult.accepted);
        verify(() => mockLogger.debug('=> All dependencies are up to date'));
        verifyNever(() => mockLogger.info(any()));
      });

      test('rejects if lockfile is missing', () async {
        when(() => mockResolver.file('pubspec.yaml')).thenAnswer((i) {
          final res = MockFile();
          when(() => res.readAsString()).thenAnswer(
            (i) async => '''
name: pull_up
''',
          );
          return res;
        });

        when(
          () => mockLockfileResolver.findWorkspaceLockfile(),
        ).thenReturnAsync(null);

        final result = await sut([]);
        expect(result, TaskResult.rejected);
        verifyNever(() => mockLogger.info(any()));
      });
    });
  });
}
