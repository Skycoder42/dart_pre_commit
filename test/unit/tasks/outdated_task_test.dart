import 'dart:convert';

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

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockTaskLogger extends Mock implements TaskLogger {}

void main() {
  group('$OutdatedConfig', () {
    testData<(Map<String, dynamic>, OutdatedConfig)>(
      'correctly converts from json',
      [
        const (<String, dynamic>{}, OutdatedConfig()),
        const (
          <String, dynamic>{
            'level': 'minor',
            'allowed': ['a', 'beta'],
          },
          OutdatedConfig(level: OutdatedLevel.minor, allowed: ['a', 'beta']),
        ),
      ],
      (fixture) {
        expect(OutdatedConfig.fromJson(fixture.$1), fixture.$2);
      },
    );
  });

  group('$OutdatedTask', () {
    final mockRunner = MockProgramRunner();
    final mockLogger = MockTaskLogger();
    const ignoredTestPackage = 'package-ignored';

    void whenRunner([List<PackageInfo> packages = const []]) =>
        when(() => mockRunner.stream(any(), any())).thenAnswer(
          (i) => Stream.fromFuture(
            Future.value(OutdatedInfo(packages: packages)),
          ).map((i) => i.toJson()).cast<Object?>().transform(json.encoder),
        );

    setUp(() {
      reset(mockRunner);
      reset(mockLogger);

      whenRunner();
    });

    group('OutdatedLevel', () {
      testData<(OutdatedLevel, String)>(
        'correctly generates and parses name',
        const [
          (OutdatedLevel.major, 'major'),
          (OutdatedLevel.minor, 'minor'),
          (OutdatedLevel.patch, 'patch'),
          (OutdatedLevel.any, 'any'),
        ],
        (fixture) {
          expect(fixture.$1.name, fixture.$2);
          expect(OutdatedLevel.values.byName(fixture.$2), fixture.$1);
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
        config: OutdatedConfig(level: level, allowed: [ignoredTestPackage]),
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

      testData<(OutdatedLevel, int)>(
        'correctly uses level to detect outdatedness',
        const [
          (OutdatedLevel.major, 1),
          (OutdatedLevel.minor, 2),
          (OutdatedLevel.patch, 3),
          (OutdatedLevel.any, 4),
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

          final sut = createSut(fixture.$1);
          final res = await sut(const []);

          expect(
            res,
            fixture.$2 == 0 ? TaskResult.accepted : TaskResult.rejected,
          );
          if (fixture.$2 == 0) {
            verify(() => mockLogger.debug('No required package updates found'));
          } else {
            verify(
              () => mockLogger.info(
                'Found ${fixture.$2} outdated package(s) '
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
              () => mockLogger.warn(
                'Ignored:     $ignoredTestPackage: 1.0.0 -> 1.1.0',
              ),
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
              () => mockLogger.warn(
                'Ignored:     $ignoredTestPackage: 1.0.0 -> 1.1.0',
              ),
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
  });
}
