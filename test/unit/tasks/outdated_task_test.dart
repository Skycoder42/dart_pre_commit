import 'dart:convert';

import 'package:dart_pre_commit/src/config/config.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/models/outdated/outdated_info.dart';
import 'package:dart_pre_commit/src/tasks/models/outdated/package_info.dart';
import 'package:dart_pre_commit/src/tasks/models/outdated/version_info.dart';
import 'package:dart_pre_commit/src/tasks/outdated_task.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockTaskLogger extends Mock implements TaskLogger {}

void main() {
  final mockRunner = MockProgramRunner();
  final mockLogger = MockTaskLogger();
  const ignoredTestPackage = 'package-ignored';

  void whenRunner([List<PackageInfo> packages = const []]) =>
      when(() => mockRunner.stream(any(), any())).thenAnswer(
        (i) => Stream.fromFuture(
          Future.value(
            OutdatedInfo(
              packages: packages,
            ),
          ),
        ).map((i) => i.toJson()).cast<Object?>().transform(json.encoder),
      );

  setUp(() {
    reset(mockRunner);
    reset(mockLogger);

    whenRunner();
  });

  group('OutdatedLevel', () {
    testData<Tuple2<OutdatedLevel, String>>(
      'correctly generates and parses name',
      const [
        Tuple2(OutdatedLevel.none, 'none'),
        Tuple2(OutdatedLevel.major, 'major'),
        Tuple2(OutdatedLevel.minor, 'minor'),
        Tuple2(OutdatedLevel.patch, 'patch'),
        Tuple2(OutdatedLevel.any, 'any'),
      ],
      (fixture) {
        expect(fixture.item1.name, fixture.item2);
        expect(OutdatedLevel.values.byName(fixture.item2), fixture.item1);
      },
    );

    test('throws if parse is called with invalid data', () {
      expect(
        () => OutdatedLevel.values.byName('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('outdated', () {
    OutdatedTask createSut(OutdatedLevel level) => OutdatedTask(
          programRunner: mockRunner,
          logger: mockLogger,
          config: const Config(
            allowOutdated: [ignoredTestPackage],
          ),
          outdatedLevel: level,
        );

    test('task metadata is correct', () {
      final sut = createSut(OutdatedLevel.any);
      expect(sut.taskName, 'outdated');
      expect(sut.callForEmptyEntries, true);
      expect(sut.filePattern, '');
    });

    test('Runs dart with correct arguments', () async {
      final sut = createSut(OutdatedLevel.any);
      final res = await sut.call(const []);

      expect(res, TaskResult.accepted);
      verify(
        () => mockRunner.stream('dart', [
          'pub',
          'outdated',
          '--show-all',
          '--json',
        ]),
      );
    });

    testData<Tuple2<OutdatedLevel, int>>(
      'correctly uses level to detect outdatedness',
      const [
        Tuple2(OutdatedLevel.none, 0),
        Tuple2(OutdatedLevel.major, 1),
        Tuple2(OutdatedLevel.minor, 2),
        Tuple2(OutdatedLevel.patch, 3),
        Tuple2(OutdatedLevel.any, 4),
      ],
      (fixture) async {
        whenRunner([
          PackageInfo(
            package: 'package-none',
            current: VersionInfo(version: Version(1, 0, 0)),
            resolvable: VersionInfo(version: Version(1, 0, 0)),
          ),
          PackageInfo(
            package: 'package-major',
            current: VersionInfo(version: Version(1, 0, 0)),
            resolvable: VersionInfo(version: Version(2, 0, 0)),
          ),
          PackageInfo(
            package: 'package-minor',
            current: VersionInfo(version: Version(1, 0, 0)),
            resolvable: VersionInfo(version: Version(1, 1, 0)),
          ),
          PackageInfo(
            package: 'package-patch',
            current: VersionInfo(version: Version(1, 0, 0)),
            resolvable: VersionInfo(version: Version(1, 0, 1)),
          ),
          PackageInfo(
            package: 'package-any',
            current: VersionInfo(version: Version(1, 0, 0)),
            resolvable: VersionInfo(version: Version(1, 0, 0, build: '1')),
          ),
        ]);

        final sut = createSut(fixture.item1);
        final res = await sut(const []);

        expect(
          res,
          fixture.item2 == 0 ? TaskResult.accepted : TaskResult.rejected,
        );
        if (fixture.item2 == 0) {
          verify(() => mockLogger.debug('No required package updates found'));
        } else {
          verify(
            () => mockLogger.info(
              'Found ${fixture.item2} outdated package(s) '
              'that have to be updated',
            ),
          );
        }
      },
    );

    test('Skips packages with invalid data', () async {
      whenRunner([
        const PackageInfo(package: 'p1'),
        PackageInfo(
          package: 'p2',
          current: VersionInfo(version: Version(1, 0, 0)),
        ),
        PackageInfo(
          package: 'p3',
          resolvable: VersionInfo(version: Version(1, 0, 0)),
        ),
        PackageInfo(
          package: 'p4',
          current: VersionInfo(version: Version(1, 0, 0)),
          resolvable: VersionInfo(version: Version(1, 0, 0)),
        ),
      ]);

      final sut = createSut(OutdatedLevel.any);
      final res = await sut(const []);

      expect(res, TaskResult.accepted);
      verify(() => mockLogger.warn(any())).called(3);
    });

    group('logs correct update result', () {
      test('required', () async {
        whenRunner([
          PackageInfo(
            package: 'p',
            current: VersionInfo(version: Version(1, 0, 0)),
            resolvable: VersionInfo(version: Version(1, 1, 0)),
          ),
        ]);

        final sut = createSut(OutdatedLevel.any);
        final res = await sut(const []);

        expect(res, TaskResult.rejected);
        verify(() => mockLogger.info('Required:    p: 1.0.0 -> 1.1.0'));
      });

      test('recommended', () async {
        whenRunner([
          PackageInfo(
            package: 'p',
            current: VersionInfo(version: Version(1, 0, 0)),
            resolvable: VersionInfo(version: Version(1, 1, 0)),
          ),
        ]);

        final sut = createSut(OutdatedLevel.major);
        final res = await sut(const []);

        expect(res, TaskResult.accepted);
        verify(() => mockLogger.info('Recommended: p: 1.0.0 -> 1.1.0'));
      });

      test('up to date', () async {
        whenRunner([
          PackageInfo(
            package: 'p',
            current: VersionInfo(version: Version(1, 0, 0)),
            resolvable: VersionInfo(version: Version(1, 0, 0)),
          ),
        ]);

        final sut = createSut(OutdatedLevel.any);
        final res = await sut(const []);

        expect(res, TaskResult.accepted);
        verify(() => mockLogger.debug('Up to date:  p: 1.0.0'));
      });

      group('ignored and', () {
        test('required', () async {
          whenRunner([
            PackageInfo(
              package: ignoredTestPackage,
              current: VersionInfo(version: Version(1, 0, 0)),
              resolvable: VersionInfo(version: Version(1, 1, 0)),
            ),
          ]);

          final sut = createSut(OutdatedLevel.any);
          final res = await sut(const []);

          expect(res, TaskResult.accepted);
          verify(
            () => mockLogger
                .warn('Ignored:     $ignoredTestPackage: 1.0.0 -> 1.1.0'),
          );
        });

        test('recommended', () async {
          whenRunner([
            PackageInfo(
              package: ignoredTestPackage,
              current: VersionInfo(version: Version(1, 0, 0)),
              resolvable: VersionInfo(version: Version(1, 1, 0)),
            ),
          ]);

          final sut = createSut(OutdatedLevel.major);
          final res = await sut(const []);

          expect(res, TaskResult.accepted);
          verify(
            () => mockLogger
                .warn('Ignored:     $ignoredTestPackage: 1.0.0 -> 1.1.0'),
          );
        });

        test('up to date', () async {
          whenRunner([
            PackageInfo(
              package: ignoredTestPackage,
              current: VersionInfo(version: Version(1, 0, 0)),
              resolvable: VersionInfo(version: Version(1, 0, 0)),
            ),
          ]);

          final sut = createSut(OutdatedLevel.any);
          final res = await sut(const []);

          expect(res, TaskResult.accepted);
          verify(
            () => mockLogger.debug('Up to date:  $ignoredTestPackage: 1.0.0'),
          );
        });
      });
    });
  });
}
