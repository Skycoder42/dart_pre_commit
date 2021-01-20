import 'dart:io';

import 'package:dart_pre_commit/src/file_resolver.dart';
import 'package:dart_pre_commit/src/logger.dart';
import 'package:dart_pre_commit/src/program_runner.dart';
import 'package:dart_pre_commit/src/pull_up_dependencies_task.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart'; // ignore: import_of_legacy_library_into_null_safe

import 'global_mocks.dart';
import 'pull_up_dependencies_task_test.mocks.dart';
import 'test_with_data.dart';

@GenerateMocks([
  TaskLogger,
  ProgramRunner,
  FileResolver,
  File,
])
void main() {
  final mockLogger = MockTaskLogger();
  final mockRunner = MockProgramRunner();
  final mockResolver = MockFileResolver();

  late PullUpDependenciesTask sut;

  setUp(() {
    reset(mockLogger);
    reset(mockRunner);
    reset(mockResolver);

    when(mockLogger.debug(any)).thenReturn(null);
    when(mockLogger.info(any)).thenReturn(null);

    sut = PullUpDependenciesTask(
      logger: mockLogger,
      programRunner: mockRunner,
      fileResolver: mockResolver,
    );
  });

  test('task metadata is correct', () {
    expect(sut.taskName, 'pull-up-dependencies');
    expect(sut.callForEmptyEntries, true);
  });

  testWithData<Tuple2<String, bool>>(
    'matches only dart/pubspec.yaml files',
    const [
      Tuple2('pubspec.yaml', false),
      Tuple2('pubspec.yml', false),
      Tuple2('pubspec.lock', true),
      Tuple2('pubspec.yaml.lock', false),
      Tuple2('path/pubspec.lock', false),
    ],
    (fixture) {
      expect(
        sut.filePattern.matchAsPrefix(fixture.item1),
        fixture.item2 ? isNotNull : isNull,
      );
    },
  );

  group('check if task runs', () {
    setUp(() {
      when(mockResolver.file('pubspec.yaml')).thenAnswer((i) {
        final res = MockFile();
        when(res.readAsString()).thenAnswer((i) async => '''
dependencies:
dev_dependencies:
''');
        return res;
      });

      when(mockResolver.file('pubspec.lock')).thenAnswer((i) {
        final res = MockFile();
        when(res.readAsString()).thenAnswer((i) async => '''
packages:
''');
        return res;
      });
    });

    test('processes packages if lockfile is ignored', () async {
      when(mockRunner.run(any, any)).thenAnswer((i) async => 0);
      final result = await sut([]);

      expect(result, TaskResult.accepted);
      verify(mockRunner.run('git', const [
        'check-ignore',
        'pubspec.lock',
      ]));
      verify(mockLogger.debug('Checking for updated packages...'));
      verifyNoMoreInteractions(mockLogger);
    });

    test('processes packages if lockfile is unstaged', () async {
      when(mockRunner.run(any, any)).thenAnswer((i) async => 1);

      final result = await sut([FakeEntry('pubspec.lock')]);

      expect(result, TaskResult.accepted);
      verify(mockRunner.run('git', const [
        'check-ignore',
        'pubspec.lock',
      ]));
      verify(mockLogger.debug('Checking for updated packages...'));
      verifyNoMoreInteractions(mockLogger);
    });

    test('does nothing if lockfile is tracked but unstaged', () async {
      when(mockRunner.run(any, any)).thenAnswer((i) async => 1);

      final result = await sut([]);

      expect(result, TaskResult.accepted);
      verify(mockRunner.run('git', const [
        'check-ignore',
        'pubspec.lock',
      ]));
      verifyZeroInteractions(mockLogger);
    });
  });

  group('task operation', () {
    setUp(() {
      when(mockRunner.run(any, any)).thenAnswer((i) async => 0);
    });

    test('Finds updates of pulled up versions and returns true', () async {
      when(mockResolver.file('pubspec.yaml')).thenAnswer((i) {
        final res = MockFile();
        when(res.readAsString()).thenAnswer((i) async => '''
dependencies:
  a: ^1.0.0
  b: ^1.0.0
dev_dependencies:
  d: ^1.0.0
  e: ^1.0.0
''');
        return res;
      });

      when(mockResolver.file('pubspec.lock')).thenAnswer((i) {
        final res = MockFile();
        when(res.readAsString()).thenAnswer((i) async => '''
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
''');
        return res;
      });

      final result = await sut([]);
      expect(result, TaskResult.rejected);
      verify(mockLogger.debug('Checking for updated packages...'));
      verify(mockLogger.info('  b: 1.0.0 -> 1.0.1'));
      verify(mockLogger.info('  d: 1.0.0 -> 1.1.0'));
      verify(
        mockLogger.info('2 dependencies can be pulled up to newer versions!'),
      );
      verifyNoMoreInteractions(mockLogger);
    });

    test('Prints nothing and returns true if no updates match', () async {
      when(mockResolver.file('pubspec.yaml')).thenAnswer((i) {
        final res = MockFile();
        when(res.readAsString()).thenAnswer((i) async => '''
dependencies:
  a: ^1.0.0
  b: 1.0.0
dev_dependencies:
  d: 1.0.0
  e: ^1.0.0
''');
        return res;
      });

      when(mockResolver.file('pubspec.lock')).thenAnswer((i) {
        final res = MockFile();
        when(res.readAsString()).thenAnswer((i) async => '''
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
''');
        return res;
      });

      final result = await sut([]);
      expect(result, TaskResult.accepted);
      verify(mockLogger.debug('Checking for updated packages...'));
      verifyNoMoreInteractions(mockLogger);
    });

    test('Does not crash if pubspec.lock is missing dependency', () async {
      when(mockResolver.file('pubspec.yaml')).thenAnswer((i) {
        final res = MockFile();
        when(res.readAsString()).thenAnswer((i) async => '''
dependencies:
  a: ^1.0.0
''');
        return res;
      });

      when(mockResolver.file('pubspec.lock')).thenAnswer((i) {
        final res = MockFile();
        when(res.readAsString()).thenAnswer((i) async => '''
packages:
''');
        return res;
      });

      final result = await sut([]);
      expect(result, TaskResult.accepted);
      verify(mockLogger.debug('Checking for updated packages...'));
      verifyNoMoreInteractions(mockLogger);
    });

    test('does not include prerelease versions', () async {
      when(mockResolver.file('pubspec.yaml')).thenAnswer((i) {
        final res = MockFile();
        when(res.readAsString()).thenAnswer((i) async => '''
dependencies:
  a: ^1.0.0
''');
        return res;
      });

      when(mockResolver.file('pubspec.lock')).thenAnswer((i) {
        final res = MockFile();
        when(res.readAsString()).thenAnswer((i) async => '''
packages:
  a:
    version: '1.2.0-prelease.1'
    dependency: 'direct'
''');
        return res;
      });

      final result = await sut([]);
      expect(result, TaskResult.accepted);
      verify(mockLogger.debug('Checking for updated packages...'));
      verifyNoMoreInteractions(mockLogger);
    });

    test('does include prerelease nullsafe versions', () async {
      when(mockResolver.file('pubspec.yaml')).thenAnswer((i) {
        final res = MockFile();
        when(res.readAsString()).thenAnswer((i) async => '''
dependencies:
  a: ^1.0.0
''');
        return res;
      });

      when(mockResolver.file('pubspec.lock')).thenAnswer((i) {
        final res = MockFile();
        when(res.readAsString()).thenAnswer((i) async => '''
packages:
  a:
    version: '1.2.0-nullsafety.0'
    dependency: 'direct'
''');
        return res;
      });

      final result = await sut([]);
      expect(result, TaskResult.rejected);
      verify(mockLogger.debug('Checking for updated packages...'));
      verify(mockLogger.info('  a: 1.0.0 -> 1.2.0-nullsafety.0'));
      verify(
        mockLogger.info('1 dependencies can be pulled up to newer versions!'),
      );
      verifyNoMoreInteractions(mockLogger);
    });
  });
}
