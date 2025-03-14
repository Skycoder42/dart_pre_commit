// ignore_for_file: discarded_futures

import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/format_task.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../global_mocks.dart' as mocks;

class MockProgramRunner extends Mock implements ProgramRunner {}

void main() {
  group('$FormatConfig', () {
    testData<(Map<String, dynamic>, FormatConfig)>(
      'correctly converts from json',
      [
        const (<String, dynamic>{}, FormatConfig()),
        const (<String, dynamic>{'line-length': null}, FormatConfig()),
        const (
          <String, dynamic>{'line-length': 42},
          FormatConfig(lineLength: 42),
        ),
      ],
      (fixture) {
        expect(FormatConfig.fromJson(fixture.$1), fixture.$2);
      },
    );
  });

  group('$FormatTask', () {
    final fakeEntry = mocks.fakeEntry('mock.dart');

    final mockRunner = MockProgramRunner();

    late FormatTask sut;

    setUp(() {
      reset(mockRunner);

      when(() => mockRunner.run(any(), any())).thenAnswer((_) async => 0);

      sut = FormatTask(programRunner: mockRunner, config: const FormatConfig());
    });

    test('task metadata is correct', () {
      expect(sut.taskName, 'format');
    });

    testData<(String, bool)>(
      'matches only dart/pubspec.yaml files',
      const [
        ('test1.dart', true),
        ('test/path2.dart', true),
        ('test3.g.dart', true),
        ('test4.dart.g', false),
        ('test5_dart', false),
        ('test6.dat', false),
      ],
      (fixture) {
        expect(
          sut.filePattern.matchAsPrefix(fixture.$1),
          fixture.$2 ? isNotNull : isNull,
        );
      },
    );

    test('calls dart format with correct arguments', () async {
      final res = await sut(fakeEntry);
      expect(res, TaskResult.accepted);
      verify(
        () => mockRunner.run('dart', const [
          'format',
          '--set-exit-if-changed',
          'mock.dart',
        ]),
      );
    });

    test('calls dart format with line length if given', () async {
      sut = FormatTask(
        programRunner: mockRunner,
        config: const FormatConfig(lineLength: 160),
      );

      final res = await sut(fakeEntry);
      expect(res, TaskResult.accepted);
      verify(
        () => mockRunner.run('dart', const [
          'format',
          '--set-exit-if-changed',
          '--line-length',
          '160',
          'mock.dart',
        ]),
      );
    });

    test('returns true if dart format returns 1', () async {
      when(() => mockRunner.run(any(), any())).thenAnswer((_) async => 1);
      final res = await sut(fakeEntry);
      expect(res, TaskResult.modified);
    });

    test('throws exception if dart format returns >1', () {
      when(() => mockRunner.run(any(), any())).thenAnswer((_) async => 42);
      expect(() => sut(fakeEntry), throwsA(isA<ProgramExitException>()));
    });
  });
}
