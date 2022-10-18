import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/format_task.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../global_mocks.dart';

class MockProgramRunner extends Mock implements ProgramRunner {}

void main() {
  group('$FormatConfig', () {
    testData<Tuple2<Map<String, dynamic>, FormatConfig>>(
      'correctly converts from json',
      [
        const Tuple2(<String, dynamic>{}, FormatConfig()),
        const Tuple2(<String, dynamic>{'line-length': null}, FormatConfig()),
        const Tuple2(
          <String, dynamic>{'line-length': 42},
          FormatConfig(lineLength: 42),
        ),
      ],
      (fixture) {
        expect(FormatConfig.fromJson(fixture.item1), fixture.item2);
      },
    );
  });

  group('$FormatTask', () {
    final fakeEntry = FakeEntry('mock.dart');

    final mockRunner = MockProgramRunner();

    late FormatTask sut;

    setUp(() {
      reset(mockRunner);

      // ignore: discarded_futures
      when(() => mockRunner.run(any(), any())).thenAnswer((_) async => 0);

      sut = FormatTask(
        programRunner: mockRunner,
        config: const FormatConfig(),
      );
    });

    test('task metadata is correct', () {
      expect(sut.taskName, 'format');
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
      ],
      (fixture) {
        expect(
          sut.filePattern.matchAsPrefix(fixture.item1),
          fixture.item2 ? isNotNull : isNull,
        );
      },
    );

    test('calls dart format with correct arguments', () async {
      final res = await sut(fakeEntry);
      expect(res, TaskResult.accepted);
      verify(
        () => mockRunner.run(
          'dart',
          const [
            'format',
            '--fix',
            '--set-exit-if-changed',
            'mock.dart',
          ],
        ),
      );
    });

    test('calls dart format with line length if given', () async {
      sut = FormatTask(
        programRunner: mockRunner,
        config: const FormatConfig(
          lineLength: 160,
        ),
      );

      final res = await sut(fakeEntry);
      expect(res, TaskResult.accepted);
      verify(
        () => mockRunner.run(
          'dart',
          const [
            'format',
            '--fix',
            '--set-exit-if-changed',
            '--line-length',
            '160',
            'mock.dart',
          ],
        ),
      );
    });

    test('returns true if dart format returns 1', () async {
      when(() => mockRunner.run(any(), any())).thenAnswer((_) async => 1);
      final res = await sut(fakeEntry);
      expect(res, TaskResult.modified);
    });

    test('throws exception if dart format returns >1', () async {
      when(() => mockRunner.run(any(), any())).thenAnswer((_) async => 42);
      expect(() => sut(fakeEntry), throwsA(isA<ProgramExitException>()));
    });
  });
}
