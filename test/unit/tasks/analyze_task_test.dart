import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/analyze_task.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../global_mocks.dart';

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockFileResolver extends Mock implements FileResolver {}

class MockTaskLogger extends Mock implements TaskLogger {}

void main() {
  final mockLogger = MockTaskLogger();
  final mockRunner = MockProgramRunner();
  final mockResolver = MockFileResolver();

  late AnalyzeTask sut;

  setUp(() {
    reset(mockLogger);
    reset(mockRunner);
    reset(mockResolver);

    when(
      () => mockRunner.stream(
        any(),
        any(),
        failOnExit: any(named: 'failOnExit'),
      ),
    ).thenAnswer((_) => Stream.fromIterable(const []));

    // ignore: discarded_futures
    when(() => mockResolver.resolve(any()))
        .thenAnswer((i) async => i.positionalArguments.first as String);
    when(() => mockResolver.resolveAll(any())).thenAnswer(
      (i) =>
          Stream.fromIterable(i.positionalArguments.first as Iterable<String>),
    );

    sut = AnalyzeTask(
      logger: mockLogger,
      programRunner: mockRunner,
      fileResolver: mockResolver,
      config: const AnalyzeConfig(),
    );
  });

  test('task metadata is correct', () {
    expect(sut.taskName, 'analyze');
    expect(sut.callForEmptyEntries, false);
  });

  testData<Tuple2<String, bool>>(
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

  testData<Tuple2<AnalyzeErrorLevel, List<String>>>(
    'Runs dart analyze with correct arguments',
    const [
      Tuple2(AnalyzeErrorLevel.error, ['analyze', '--no-fatal-warnings']),
      Tuple2(AnalyzeErrorLevel.warning, ['analyze', '--fatal-warnings']),
      Tuple2(
        AnalyzeErrorLevel.info,
        ['analyze', '--fatal-warnings', '--fatal-infos'],
      ),
    ],
    (fixture) async {
      sut = AnalyzeTask(
        logger: mockLogger,
        programRunner: mockRunner,
        fileResolver: mockResolver,
        config: AnalyzeConfig(errorLevel: fixture.item1),
      );

      final result = await sut([
        FakeEntry('test.dart'),
      ]);

      expect(result, TaskResult.accepted);
      verify(
        () => mockRunner.stream(
          'dart',
          fixture.item2,
          failOnExit: false,
        ),
      );
    },
  );

  test('Collects lints for specified files', () async {
    when(
      () => mockRunner.stream(
        any(),
        any(),
        failOnExit: any(named: 'failOnExit'),
      ),
    ).thenAnswer(
      (_) => Stream.fromIterable(const [
        '  A - a.dart:10:11 - a1 - 1',
        '  A - a-a-a.dart:88:99 - a2 - a2-a2 - 2',
        '  this is an invalid line',
        '  B - b/b.dart:30:31 - b3 - 3',
        '  C - c/c/c.dart:40:41 - c4 - 4',
        '  D - pubspec.yaml:50:51 - d5 - 5',
      ]),
    );

    final result = await sut([
      FakeEntry('a.dart'),
      FakeEntry('a-a-a.dart'),
      FakeEntry('b/b.dart'),
      FakeEntry('c/c/d.dart'),
      FakeEntry('pubspec.yaml'),
      FakeEntry('b/a.js'),
      FakeEntry('pipeline.yaml'),
    ]);
    expect(result, TaskResult.rejected);
    verifyInOrder([
      () => mockLogger.info('  A - a.dart:10:11 - a1 - 1'),
      () => mockLogger.info('  A - a-a-a.dart:88:99 - a2 - a2-a2 - 2'),
      () => mockLogger.info('  B - b/b.dart:30:31 - b3 - 3'),
      () => mockLogger.info('  D - pubspec.yaml:50:51 - d5 - 5'),
      () => mockLogger.info('4 issue(s) found.'),
    ]);
    verifyNever(() => mockLogger.info(any()));
  });

  test('Succeeds if only lints of not specified files are found', () async {
    when(
      () => mockRunner.stream(
        any(),
        any(),
        failOnExit: any(named: 'failOnExit'),
      ),
    ).thenAnswer(
      (_) => Stream.fromIterable([
        '  B - b3 at b/b.dart:30:31 - (3)',
      ]),
    );

    final result = await sut([FakeEntry('a.dart')]);
    expect(result, TaskResult.accepted);
    verify(() => mockLogger.info(any())).called(1);
  });
}
