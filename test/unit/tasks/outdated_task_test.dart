import 'dart:convert';

import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/models/outdated/outdated_info.dart';
import 'package:dart_pre_commit/src/tasks/models/outdated/package_info.dart';
import 'package:dart_pre_commit/src/tasks/models/outdated/version_info.dart';
import 'package:dart_pre_commit/src/tasks/outdated_task.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../test_with_data.dart';

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockTaskLogger extends Mock implements TaskLogger {}

void main() {
  final mockRunner = MockProgramRunner();
  final mockLogger = MockTaskLogger();

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
    testWithData<Tuple2<OutdatedLevel, String>>(
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
        expect(OutdatedLevelX.parse(fixture.item2), fixture.item1);
      },
    );

    test('throws if parse is called with invalid data', () {
      expect(
        () => OutdatedLevelX.parse('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('outdated', () {
    OutdatedTask _sut(OutdatedLevel level) => OutdatedTask(
          programRunner: mockRunner,
          logger: mockLogger,
          outdatedLevel: level,
        );

    test('task metadata is correct', () {
      final sut = _sut(OutdatedLevel.any);
      expect(sut.taskName, 'outdated');
      expect(sut.callForEmptyEntries, true);
      expect(sut.filePattern, '');
    });

    test('Runs dart with correct arguments', () async {
      final sut = _sut(OutdatedLevel.any);
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

    testWithData<Tuple2<OutdatedLevel, int>>(
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

        final sut = _sut(fixture.item1);
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
          package: 'p2',
          current: VersionInfo(version: Version(1, 0, 0)),
          resolvable: VersionInfo(version: Version(1, 0, 0)),
        ),
      ]);

      final sut = _sut(OutdatedLevel.any);
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

        final sut = _sut(OutdatedLevel.any);
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

        final sut = _sut(OutdatedLevel.major);
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

        final sut = _sut(OutdatedLevel.any);
        final res = await sut(const []);

        expect(res, TaskResult.accepted);
        verify(() => mockLogger.debug('Up to date:  p: 1.0.0'));
      });
    });
  });

  group('nullsafe', () {
    late NullsafeTask sut;

    setUp(() {
      sut = NullsafeTask(
        logger: mockLogger,
        programRunner: mockRunner,
      );
    });

    test('task metadata is correct', () {
      expect(sut.taskName, 'nullsafe');
      expect(sut.callForEmptyEntries, true);
      expect(sut.filePattern, '');
    });

    test('Runs dart with correct arguments', () async {
      final res = await sut.call(const []);

      expect(res, TaskResult.accepted);
      verify(
        () => mockRunner.stream('dart', [
          'pub',
          'outdated',
          '--show-all',
          '--json',
          '--mode=null-safety',
        ]),
      );
    });

    test('Skips invalid packages', () async {
      whenRunner(const [
        PackageInfo(package: 'invalid'),
      ]);

      final res = await sut(const []);

      expect(res, TaskResult.accepted);
      verify(
        () => mockLogger.warn(
          'Skipping:    invalid: No Version information available',
        ),
      );
    });

    test('Skips already nullsafe packages', () async {
      whenRunner([
        PackageInfo(
          package: 'safe',
          current: VersionInfo(
            version: Version(1, 0, 0),
            nullSafety: true,
          ),
        ),
      ]);

      final res = await sut(const []);

      expect(res, TaskResult.accepted);
      verify(
        () => mockLogger.debug(
          'Up to date:  safe: 1.0.0 is nullsafe',
        ),
      );
    });

    test('Counts nullsafe resolvable', () async {
      whenRunner([
        PackageInfo(
          package: 'resolvable',
          current: VersionInfo(
            version: Version(1, 0, 0),
            nullSafety: false,
          ),
          resolvable: VersionInfo(
            version: Version(1, 0, 0, pre: 'nullsafety.0'),
            nullSafety: true,
          ),
        ),
      ]);

      final res = await sut(const []);

      expect(res, TaskResult.rejected);
      verify(
        () => mockLogger.info(
          'Upgradeable: resolvable: 1.0.0 -> 1.0.0-nullsafety.0',
        ),
      );
    });

    test('Informs about non-resolvable nullsafe packages', () async {
      whenRunner([
        PackageInfo(
          package: 'latest',
          current: VersionInfo(
            version: Version(1, 0, 0),
          ),
          latest: VersionInfo(
            version: Version(1, 0, 0, pre: 'nullsafety.0'),
            nullSafety: true,
          ),
        ),
      ]);

      final res = await sut(const []);

      expect(res, TaskResult.accepted);
      verify(
        () => mockLogger.info(
          'Available:   latest: 1.0.0 -> 1.0.0-nullsafety.0',
        ),
      );
    });

    test('Skips unavailable packages', () async {
      whenRunner([
        PackageInfo(
          package: 'unavailable',
          current: VersionInfo(
            version: Version(1, 0, 0),
            nullSafety: false,
          ),
        ),
      ]);

      final res = await sut(const []);

      expect(res, TaskResult.accepted);
      verify(
        () => mockLogger.debug(
          'Skipping:    unavailable: No nullsafe version available',
        ),
      );
    });

    test('correctly counts packages', () async {
      whenRunner([
        PackageInfo(
          package: 'p1',
          current: VersionInfo(version: Version(1, 0, 0)),
        ),
        PackageInfo(
          package: 'p2',
          current: VersionInfo(version: Version(1, 0, 0)),
          resolvable: VersionInfo(
            version: Version(1, 0, 0, pre: 'nullsafety.0'),
            nullSafety: true,
          ),
        ),
        PackageInfo(
          package: 'p3',
          current: VersionInfo(version: Version(1, 0, 0)),
        ),
        PackageInfo(
          package: 'p4',
          current: VersionInfo(version: Version(1, 0, 0)),
          resolvable: VersionInfo(
            version: Version(1, 0, 0, pre: 'nullsafety.0'),
            nullSafety: true,
          ),
        ),
        PackageInfo(
          package: 'p4',
          current: VersionInfo(version: Version(1, 0, 0)),
        ),
      ]);

      final res = await sut(const []);

      expect(res, TaskResult.rejected);
      verify(
        () => mockLogger.info(
          'Found 2 upgradeble null-safe package(s)',
        ),
      );
    });
  });
}
