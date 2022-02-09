import 'dart:io';

import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/flutter_compat_task.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../test_with_data.dart';
import '../global_mocks.dart';

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockTaskLogger extends Mock implements TaskLogger {}

class MockFile extends Mock implements File {}

class FakeDirectory extends Fake implements Directory {
  @override
  final String path;

  FakeDirectory(this.path);
}

class MockRepoEntry extends Mock implements RepoEntry {}

abstract class IPubspecParseFactory {
  Pubspec call(String yaml, {Uri? sourceUrl, bool lenient});
}

class MockPubspecParseFactory extends Mock implements IPubspecParseFactory {}

void main() {
  group('FlutterCompatTask', () {
    final mockProgramRunner = MockProgramRunner();
    final mockTaskLogger = MockTaskLogger();
    final mockPubspecParseFactory = MockPubspecParseFactory();
    final mockFile = MockFile();
    final mockRepoEntry = MockRepoEntry();

    late FlutterCompatTask sut;

    setUp(() {
      reset(mockProgramRunner);
      reset(mockTaskLogger);
      reset(mockPubspecParseFactory);
      reset(mockFile);
      reset(mockRepoEntry);

      when(() => mockRepoEntry.file).thenReturn(mockFile);

      sut = FlutterCompatTask(
        programRunner: mockProgramRunner,
        taskLogger: mockTaskLogger,
        pubspecParseFactory: mockPubspecParseFactory,
      );
    });

    test('task metadata is correct', () {
      expect(sut.taskName, 'flutter-compat');
      expect(sut.callForEmptyEntries, isFalse);
    });

    group('canProcess', () {
      testWithData<String>(
        'does not match non pubspec files',
        const ['pubspec.yarml', 'pubspec.lock'],
        (fixture) {
          expect(sut.canProcess(FakeEntry(fixture)), isFalse);
        },
      );

      testWithData<Tuple2<String, bool>>(
        'Does only match non flutter pubspec',
        const [
          Tuple2('not_flutter', true),
          Tuple2('flutter', false),
        ],
        (fixture) {
          when(() => mockFile.path).thenReturn('pubspec.yaml');
          when(() => mockFile.uri).thenReturn(Uri.file('pubspec.yaml'));
          when(() => mockFile.readAsStringSync()).thenReturn('pubspec-yaml');
          when(
            () => mockPubspecParseFactory.call(
              any(),
              sourceUrl: any(named: 'sourceUrl'),
              lenient: any(named: 'lenient'),
            ),
          ).thenReturn(
            Pubspec(
              'name',
              dependencies: {
                fixture.item1: HostedDependency(),
              },
            ),
          );

          expect(sut.canProcess(mockRepoEntry), fixture.item2);

          verifyInOrder([
            () => mockFile.path,
            () => mockFile.readAsStringSync(),
            () => mockFile.uri,
            () => mockPubspecParseFactory.call(
                  'pubspec-yaml',
                  sourceUrl: Uri.file('pubspec.yaml'),
                ),
          ]);
        },
      );
    });

    group('call', () {
      final testUri = Uri.file('pubspec.yaml');
      const testContent = 'pubspec-yaml';
      const dependencyName = 'test_project';
      const dependencyPath = '/path/to/project';

      Matcher isSystemTempDir() =>
          predicate<String>((s) => isWithin(Directory.systemTemp.path, s));

      setUp(() {
        when(() => mockFile.uri).thenReturn(testUri);
        when(() => mockFile.readAsString())
            .thenAnswer((i) async => testContent);
        when(
          () => mockPubspecParseFactory.call(
            any(),
            sourceUrl: any(named: 'sourceUrl'),
          ),
        ).thenReturn(Pubspec(dependencyName));
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
