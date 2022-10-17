import 'dart:convert';

import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/analyze_task.dart';
import 'package:dart_pre_commit/src/tasks/models/analyze/analyze_result.dart';
import 'package:dart_pre_commit/src/tasks/models/analyze/diagnostic.dart';
import 'package:dart_pre_commit/src/tasks/models/analyze/location.dart';
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

const fullAnalyzeResult = AnalyzeResult(
  version: 1,
  diagnostics: [
    Diagnostic(
      code: 'A',
      severity: DiagnosticSeverity.error,
      type: DiagnosticType.syntacticError,
      location: Location(
        file: 'a.dart',
        range: Range(
          start: RangePosition(line: 10, column: 11, offset: 0),
          end: RangePosition(line: 10, column: 12, offset: 0),
        ),
      ),
      problemMessage: 'a1',
      correctionMessage: '1',
      documentation: null,
    ),
    Diagnostic(
      code: 'A',
      severity: DiagnosticSeverity.warning,
      type: DiagnosticType.syntacticError,
      location: Location(
        file: 'a-a-a.dart',
        range: Range(
          start: RangePosition(line: 88, column: 99, offset: 0),
          end: RangePosition(line: 99, column: 88, offset: 0),
        ),
      ),
      problemMessage: 'a2 - a2-a2',
      correctionMessage: '2',
      documentation: null,
    ),
    Diagnostic(
      code: 'B',
      severity: DiagnosticSeverity.info,
      type: DiagnosticType.syntacticError,
      location: Location(
        file: 'b/b.dart',
        range: Range(
          start: RangePosition(line: 30, column: 31, offset: 0),
          end: RangePosition(line: 32, column: 33, offset: 0),
        ),
      ),
      problemMessage: 'b3',
      correctionMessage: '3',
      documentation: null,
    ),
    Diagnostic(
      code: 'C',
      severity: DiagnosticSeverity.warning,
      type: DiagnosticType.syntacticError,
      location: Location(
        file: 'c/c/c.dart',
        range: Range(
          start: RangePosition(line: 40, column: 41, offset: 0),
          end: RangePosition(line: 42, column: 43, offset: 0),
        ),
      ),
      problemMessage: 'c4',
      correctionMessage: '4',
      documentation: null,
    ),
    Diagnostic(
      code: 'D',
      severity: DiagnosticSeverity.none,
      type: DiagnosticType.syntacticError,
      location: Location(
        file: 'pubspec.yaml',
        range: Range(
          start: RangePosition(line: 50, column: 51, offset: 0),
          end: RangePosition(line: 50, column: 51, offset: 0),
        ),
      ),
      problemMessage: 'd5',
      correctionMessage: '5',
      documentation: null,
    ),
  ],
);

const minimalAnalyzeResult = AnalyzeResult(
  version: 1,
  diagnostics: [
    Diagnostic(
      code: 'O',
      severity: DiagnosticSeverity.error,
      type: DiagnosticType.compileTimeError,
      location: Location(
        file: 'o.dart',
        range: Range(
          start: RangePosition(line: 0, column: 0, offset: 0),
          end: RangePosition(line: 1, column: 0, offset: 0),
        ),
      ),
      problemMessage: 'o',
      correctionMessage: null,
      documentation: null,
    ),
  ],
);

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
    ).thenAnswer(
      (_) => Stream.value(
        json.encode(const AnalyzeResult(version: 1, diagnostics: [])),
      ),
    );

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
      config: const AnalyzeConfig(scanMode: AnalysisScanMode.staged),
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
      Tuple2(AnalyzeErrorLevel.error, ['--no-fatal-warnings']),
      Tuple2(AnalyzeErrorLevel.warning, ['--fatal-warnings']),
      Tuple2(
        AnalyzeErrorLevel.info,
        ['--fatal-warnings', '--fatal-infos'],
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
          ['analyze', '--format', 'json', ...fixture.item2],
          failOnExit: false,
        ),
      );
    },
  );

  group('staged', () {
    test('collects lints for specified files', () async {
      when(
        () => mockRunner.stream(
          any(),
          any(),
          failOnExit: any(named: 'failOnExit'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          'this is an invalid line',
          '    this as well  ',
          json.encode(fullAnalyzeResult),
          'also this',
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
      verify(() => mockLogger.info('  error - a.dart:10:11 - a1 1 - A'));
      verify(
        () => mockLogger.info(
          '  warning - a-a-a.dart:88:99 - a2 - a2-a2 2 - A',
        ),
      );
      verify(() => mockLogger.info('  info - b/b.dart:30:31 - b3 3 - B'));
      verify(() => mockLogger.info('  none - pubspec.yaml:50:51 - d5 5 - D'));
      verify(() => mockLogger.info('4 issue(s) found.'));
      verifyNever(() => mockLogger.info(any()));
    });

    test('succeeds if only lints of not specified files are found', () async {
      when(
        () => mockRunner.stream(
          any(),
          any(),
          failOnExit: any(named: 'failOnExit'),
        ),
      ).thenAnswer((_) => Stream.value(json.encode(minimalAnalyzeResult)));

      final result = await sut([FakeEntry('a.dart')]);
      expect(result, TaskResult.accepted);
      verify(() => mockLogger.info(any())).called(1);
    });
  });

  group('collections lints for all files', () {
    setUp(() {
      sut = AnalyzeTask(
        logger: mockLogger,
        programRunner: mockRunner,
        fileResolver: mockResolver,
        config: const AnalyzeConfig(scanMode: AnalysisScanMode.all),
      );
    });

    test('collects lints for specified files', () async {
      when(
        () => mockRunner.stream(
          any(),
          any(),
          failOnExit: any(named: 'failOnExit'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          'this is an invalid line',
          '    this as well  ',
          json.encode(fullAnalyzeResult),
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
        () => mockLogger.info('  error - a.dart:10:11 - a1 1 - A'),
        () =>
            mockLogger.info('  warning - a-a-a.dart:88:99 - a2 - a2-a2 2 - A'),
        () => mockLogger.info('  info - b/b.dart:30:31 - b3 3 - B'),
        () => mockLogger.info('  warning - c/c/c.dart:40:41 - c4 4 - C'),
        () => mockLogger.info('  none - pubspec.yaml:50:51 - d5 5 - D'),
        () => mockLogger.info('5 issue(s) found.'),
      ]);
      verifyNever(() => mockLogger.info(any()));
    });

    test('fails if only lints of not specified files are found', () async {
      when(
        () => mockRunner.stream(
          any(),
          any(),
          failOnExit: any(named: 'failOnExit'),
        ),
      ).thenAnswer((_) => Stream.value(json.encode(minimalAnalyzeResult)));

      final result = await sut([FakeEntry('a.dart')]);
      expect(result, TaskResult.rejected);
      verifyInOrder([
        () => mockLogger.info('  error - o.dart:0:0 - o - O'),
        () => mockLogger.info('1 issue(s) found.'),
      ]);
      verifyNever(() => mockLogger.info(any()));
    });
  });
}
