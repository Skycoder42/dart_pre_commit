// ignore_for_file: unnecessary_lambdas

import 'dart:convert';
import 'dart:io';

import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/lockfile_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/models/workspace.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

class MockFile extends Mock implements File {
  @override
  Uri get uri => Uri();
}

class MockTaskLogger extends Mock implements TaskLogger {}

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockFileResolver extends Mock implements FileResolver {}

void main() {
  group('$LockfileResolver', () {
    final mockLogger = MockTaskLogger();
    final mockRunner = MockProgramRunner();
    final mockResolver = MockFileResolver();

    late LockfileResolver sut;

    setUp(() {
      reset(mockLogger);
      reset(mockRunner);
      reset(mockResolver);

      sut = LockfileResolver(
        programRunner: mockRunner,
        fileResolver: mockResolver,
        logger: mockLogger,
      );
    });

    group('findWorkspaceLockfile', () {
      setUp(() {
        when(
          () => mockResolver.file(any(that: endsWith('pubspec.lock'))),
        ).thenAnswer((i) {
          final [String path] = i.positionalArguments;
          final res = MockFile();
          when(() => res.path).thenReturn(path);
          when(() => res.existsSync()).thenReturn(path.contains('found'));
          return res;
        });
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

        final result = await sut.findWorkspaceLockfile();
        expect(result, isA<MockFile>());
        verifyInOrder([
          () => mockRunner.stream('dart', [
            'pub',
            'workspace',
            'list',
            '--json',
          ], runInShell: true),
          () => mockResolver.file('/test/not${path.separator}pubspec.lock'),
          () => mockResolver.file('/test/found1${path.separator}pubspec.lock'),
          () => mockLogger.debug(
            'Detected workspace lockfile as: /test/found1${path.separator}pubspec.lock',
          ),
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

        final result = await sut.findWorkspaceLockfile();
        expect(result, isNull);
        verifyInOrder([
          () => mockRunner.stream('dart', [
            'pub',
            'workspace',
            'list',
            '--json',
          ], runInShell: true),
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

        final result = await sut.findWorkspaceLockfile();
        expect(result, isNull);
        verifyInOrder([
          () => mockRunner.stream('dart', [
            'pub',
            'workspace',
            'list',
            '--json',
          ], runInShell: true),
          () => mockResolver.file('/test${path.separator}pubspec.lock'),
          () => mockResolver.file('/test/not1${path.separator}pubspec.lock'),
          () => mockResolver.file('/test/not2${path.separator}pubspec.lock'),
          () => mockLogger.error('Failed to find pubspec.lock in workspace'),
        ]);
        verifyNever(() => mockResolver.file(any()));
      });
    });
  });
}
