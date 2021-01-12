import 'package:dart_pre_commit/src/analyze_task.dart';
import 'package:dart_pre_commit/src/file_resolver.dart';
import 'package:dart_pre_commit/src/logger.dart';
import 'package:dart_pre_commit/src/program_runner.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart'; // ignore: import_of_legacy_library_into_null_safe

import 'analyze_task_test.mocks.dart';
import 'global_mocks.dart';
import 'test_with_data.dart';

@GenerateMocks([
  ProgramRunner,
  FileResolver,
], customMocks: [
  MockSpec<Logger>(returnNullOnMissingStub: true),
])
void main() {
  final mockLogger = MockLogger();
  final mockRunner = MockProgramRunner();
  final mockFileResolver = MockFileResolver();

  late AnalyzeTask sut;

  setUp(() {
    reset(mockLogger);
    reset(mockRunner);
    reset(mockFileResolver);

    when(mockRunner.stream(
      any,
      any,
      failOnExit: anyNamed('failOnExit'),
    )).thenAnswer((_) => Stream.fromIterable(const []));

    when(mockFileResolver.resolve(any))
        .thenAnswer((i) async => i.positionalArguments.first as String);
    when(mockFileResolver.resolveAll(any)).thenAnswer((i) =>
        Stream.fromIterable(i.positionalArguments.first as Iterable<String>));

    sut = AnalyzeTask(
      logger: mockLogger,
      programRunner: mockRunner,
      fileResolver: mockFileResolver,
    );
  });

  test('task metadata is correct', () {
    expect(sut.taskName, 'analyze');
    expect(sut.callForEmptyEntries, false);
  });

  testWithData<Tuple2<String, bool>>(
    'matches only dart/pubspec.yaml files',
    const [
      Tuple2('test1.dart', true),
      Tuple2('test/path2.dart', true),
      Tuple2('test3.g.dart', true),
      Tuple2('test4.dart.g', false),
      Tuple2('test5_dart', false),
      Tuple2('test6.dat', false),
      Tuple2('pubspec.yaml', true),
      Tuple2('pubspec.yml', true),
      Tuple2('pubspec.lock', false),
      Tuple2('path/pubspec.yaml', false),
    ],
    (fixture) {
      expect(
        sut.filePattern.matchAsPrefix(fixture.item1),
        fixture.item2 ? isNotNull : isNull,
      );
    },
  );

  test('Run dartanalyzer with correct arguments', () async {
    final result = await sut([
      FakeEntry('test.dart'),
    ]);

    expect(result, false);
    verify(mockRunner.stream(
      'dart',
      const [
        'analyze',
        '--fatal-infos',
      ],
      failOnExit: false,
    ));
  });

  test('Collects lints for specified files', () async {
    when(mockRunner.stream(
      any,
      any,
      failOnExit: anyNamed('failOnExit'),
    )).thenAnswer(
      (_) => Stream.fromIterable(const [
        '  A - a1 at a.dart:10:11 - (1)',
        '  A - a2 at a.dart:88:99 at at a.dart:20:21 - (2)',
        '  B - b3 at b/b.dart:30:31 - (3)',
        '  C - c4 at c/c/c.dart:40:41 - (4)',
        '  D - d5 at pubspec.yaml:50:51 - (5)',
      ]),
    );

    final result = await sut([
      FakeEntry('a.dart'),
      FakeEntry('b/b.dart'),
      FakeEntry('c/c/d.dart'),
      FakeEntry('pubspec.yaml'),
      FakeEntry('b/a.js'),
      FakeEntry('pipeline.yaml'),
    ]);
    expect(result, true);
    verify(mockLogger.log('Running dart analyze...'));
    verify(mockLogger.log('  A - a1 at a.dart:10:11 - (1)'));
    verify(mockLogger.log('  A - a2 at a.dart:88:99 at at a.dart:20:21 - (2)'));
    verify(mockLogger.log('  B - b3 at b/b.dart:30:31 - (3)'));
    verify(mockLogger.log('  D - d5 at pubspec.yaml:50:51 - (5)'));
    verify(mockLogger.log('4 issue(s) found.'));
    verifyNoMoreInteractions(mockLogger);
  });

  test('Succeeds if only lints of not specified files are found', () async {
    when(mockRunner.stream(
      any,
      any,
      failOnExit: anyNamed('failOnExit'),
    )).thenAnswer(
      (_) => Stream.fromIterable([
        '  B - b3 at b/b.dart:30:31 - (3)',
      ]),
    );

    final result = await sut([FakeEntry('a.dart')]);
    expect(result, false);
    verify(mockLogger.log(any)).called(2);
  });
}
