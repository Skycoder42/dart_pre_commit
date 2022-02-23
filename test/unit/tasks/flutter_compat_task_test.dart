import 'dart:io';

import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/flutter_compat_task.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../global_mocks.dart';

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockTaskLogger extends Mock implements TaskLogger {}

class MockFile extends Mock implements File {}

class FakeDirectory extends Fake implements Directory {
  @override
  final String path;

  @override
  Directory get absolute => FakeDirectory(path);

  FakeDirectory(this.path);
}

class MockRepoEntry extends Mock implements RepoEntry {}

void main() {
  group('FlutterCompatTask', () {
    final mockProgramRunner = MockProgramRunner();
    final mockTaskLogger = MockTaskLogger();
    final mockFile = MockFile();
    final mockRepoEntry = MockRepoEntry();

    late FlutterCompatTask sut;

    setUp(() {
      reset(mockProgramRunner);
      reset(mockTaskLogger);
      reset(mockFile);
      reset(mockRepoEntry);

      when(() => mockRepoEntry.file).thenReturn(mockFile);

      sut = FlutterCompatTask(
        programRunner: mockProgramRunner,
        taskLogger: mockTaskLogger,
      );
    });

    test('task metadata is correct', () {
      expect(sut.taskName, 'flutter-compat');
      expect(sut.callForEmptyEntries, isFalse);
    });

    group('canProcess', () {
      testData<String>(
        'does not match non pubspec files',
        const ['pubspec.yarml', 'pubspec.lock'],
        (fixture) {
          expect(sut.canProcess(FakeEntry(fixture)), isFalse);
        },
      );

      testData<Tuple2<String, bool>>(
        'Does only match non flutter pubspec',
        const [
          Tuple2('not_flutter', true),
          Tuple2('flutter', false),
        ],
        (fixture) {
          when(() => mockFile.path).thenReturn('pubspec.yaml');
          when(() => mockFile.uri).thenReturn(Uri.file('pubspec.yaml'));
          when(() => mockFile.readAsStringSync()).thenReturn(
            '''
name: name
dependencies:
  ${fixture.item1}: null
''',
          );

          expect(sut.canProcess(mockRepoEntry), fixture.item2);

          verifyInOrder([
            () => mockFile.path,
            () => mockFile.readAsStringSync(),
            () => mockFile.uri,
          ]);
        },
      );
    });

    group('call', () {
      final testUri = Uri.file('pubspec.yaml');
      const dependencyName = 'test_project';
      const testContent = 'name: $dependencyName\n';
      const dependencyPath = '/path/to/project';

      Matcher isSystemTempDir() =>
          predicate<String>((s) => isWithin(Directory.systemTemp.path, s));

      setUp(() {
        when(() => mockFile.uri).thenReturn(testUri);
        when(() => mockFile.readAsString())
            .thenAnswer((i) async => testContent);
        when(() => mockFile.parent).thenReturn(FakeDirectory(dependencyPath));
        when(
          () => mockProgramRunner.run(
            any(),
            any(),
            workingDirectory: any(named: 'workingDirectory'),
            failOnExit: any(named: 'failOnExit'),
          ),
        ).thenAnswer((i) async => 0);
      });

      test(
        'Creates a new flutter project with the current project as dependency',
        () async {
          await sut.call([mockRepoEntry]);

          verifyInOrder([
            () => mockRepoEntry.file,
            () => mockFile.readAsString(),
            () => mockRepoEntry.file,
            () => mockFile.uri,
            () => mockProgramRunner.run(
                  'flutter',
                  const ['create', '--project-name', 't', '.'],
                  workingDirectory: any(
                    named: 'workingDirectory',
                    that: isSystemTempDir(),
                  ),
                  failOnExit: true,
                ),
            () => mockFile.parent,
            () => mockProgramRunner.run(
                  'flutter',
                  const [
                    'pub',
                    'add',
                    dependencyName,
                    '--path',
                    dependencyPath,
                  ],
                  workingDirectory: any(
                    named: 'workingDirectory',
                    that: isSystemTempDir(),
                  ),
                ),
          ]);
        },
      );

      test('returns accepted if dependency can be added', () async {
        final result = await sut.call([mockRepoEntry]);
        expect(result, TaskResult.accepted);
      });

      test('returns rejected if dependency can not be added', () async {
        const exitCode = 42;
        when(
          () => mockProgramRunner.run(
            any(),
            any(),
            workingDirectory: any(named: 'workingDirectory'),
          ),
        ).thenAnswer((i) async => exitCode);

        final result = await sut.call([mockRepoEntry]);
        expect(result, TaskResult.rejected);

        verify(
          () => mockTaskLogger.error(
            any(
              that: allOf(
                contains(dependencyName),
                contains(exitCode.toString()),
              ),
            ),
          ),
        );
      });

      test('Throws if flutter project cannot be created', () async {
        final result = await sut.call([mockRepoEntry]);
        expect(result, TaskResult.accepted);
        when(
          () => mockProgramRunner.run(
            any(),
            any(),
            workingDirectory: any(named: 'workingDirectory'),
            failOnExit: true,
          ),
        ).thenThrow(Exception('FAILURE'));

        expect(
          () => sut.call([mockRepoEntry]),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
