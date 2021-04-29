import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/analyze_task.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../test_with_data.dart';
import '../global_mocks.dart';
import 'analyze_task_test.mocks.dart';

@GenerateMocks([
  ProgramRunner,
  FileResolver,
], customMocks: [
  MockSpec<TaskLogger>(returnNullOnMissingStub: true),
])
void main() {
  final mockLogger = MockTaskLogger();
  final mockRunner = MockProgramRunner();
  final mockResolver = MockFileResolver();

  late AnalyzeTask sut;

  setUp(() {
    reset(mockLogger);
    reset(mockRunner);
    reset(mockResolver);

    when(mockRunner.stream(
      any,
      any,
      failOnExit: anyNamed('failOnExit'),
    )).thenAnswer((_) => Stream.fromIterable(const []));

    when(mockResolver.resolve(any))
        .thenAnswer((i) async => i.positionalArguments.first as String);
    when(mockResolver.resolveAll(any)).thenAnswer((i) =>
        Stream.fromIterable(i.positionalArguments.first as Iterable<String>));

    sut = AnalyzeTask(
      logger: mockLogger,
      programRunner: mockRunner,
      fileResolver: mockResolver,
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

    expect(result, TaskResult.accepted);
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
        '  this is an invalid line',
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
    expect(result, TaskResult.rejected);
    verify(mockLogger.info('  A - a1 at a.dart:10:11 - (1)'));
    verify(
      mockLogger.info('  A - a2 at a.dart:88:99 at at a.dart:20:21 - (2)'),
    );
    verify(mockLogger.info('  B - b3 at b/b.dart:30:31 - (3)'));
    verify(mockLogger.info('  D - d5 at pubspec.yaml:50:51 - (5)'));
    verify(mockLogger.info('4 issue(s) found.'));
    verifyNever(mockLogger.info(any));
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
    expect(result, TaskResult.accepted);
    verify(mockLogger.info(any)).called(1);
  });
}
