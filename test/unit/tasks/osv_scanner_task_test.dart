import 'dart:convert';

import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/models/osv_scanner/osv_scanner_result.dart';
import 'package:dart_pre_commit/src/tasks/models/osv_scanner/package.dart';
import 'package:dart_pre_commit/src/tasks/models/osv_scanner/package_info.dart';
import 'package:dart_pre_commit/src/tasks/models/osv_scanner/result.dart';
import 'package:dart_pre_commit/src/tasks/models/osv_scanner/vulnerability.dart';
import 'package:dart_pre_commit/src/tasks/osv_scanner_task.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../global_mocks.dart';
import 'flutter_compat_task_test.dart';

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockTaskLogger extends Mock implements TaskLogger {}

const osvScannerResult = OsvScannerResult(
  results: [
    Result(
      packages: [
        Package(
          package: PackageInfo(
            name: 'package_a',
            version: '1.2.3',
            ecosystem: 'Pub',
          ),
          vulnerabilities: [
            Vulnerability(
              schemaVersion: '1.3.0',
              id: 'vuln-id-1',
              summary: 'This is a serious issue',
            ),
            Vulnerability(
              schemaVersion: '1.3.0',
              id: 'vuln-id-2',
              summary: 'This is another serious issue',
            ),
          ],
        ),
        Package(
          package: PackageInfo(
            name: 'package_b',
            version: '2.0.0',
            ecosystem: 'Pub',
          ),
          vulnerabilities: [
            Vulnerability(
              schemaVersion: '1.3.0',
              id: 'vuln-id-3',
              summary: 'This is a not so serious issue',
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  group('$OsvScannerTask', () {
    final mockRunner = MockProgramRunner();
    final mockLogger = MockTaskLogger();

    late OsvScannerTask sut;

    setUp(() {
      reset(mockRunner);
      reset(mockLogger);

      when(
        () => mockRunner.stream(
          any(),
          any(),
          failOnExit: any(named: 'failOnExit'),
        ),
      ).thenAnswer(
        (_) => Stream.value(
          json.encode(const OsvScannerResult(results: [])),
        ),
      );

      sut = OsvScannerTask(
        programRunner: mockRunner,
        taskLogger: mockLogger,
      );
    });

    test('task metadata is correct', () {
      expect(sut.taskName, 'osv-scanner');
      expect(sut.callForEmptyEntries, true);
    });

    test('canProcess always returns false', () {
      expect(
        sut.canProcess(
          RepoEntry(
            file: FakeFile('pubspec.lock'),
            partiallyStaged: false,
            gitRoot: FakeDirectory('.'),
          ),
        ),
        isFalse,
      );
    });

    test('runs osv-scanner with correct arguments', () async {
      final result = await sut(const []);

      expect(result, TaskResult.accepted);
      verify(
        () => mockRunner.stream(
          'osv-scanner',
          const ['--lockfile', 'pubspec.lock', '--json'],
          failOnExit: false,
        ),
      );

      verifyNoMoreInteractions(mockRunner);
      verifyZeroInteractions(mockLogger);
    });

    test('collects vulnerabilities for package', () async {
      when(
        () => mockRunner.stream(
          any(),
          any(),
          failOnExit: any(named: 'failOnExit'),
        ),
      ).thenAnswer((_) => Stream.value(json.encode(osvScannerResult)));

      final result = await sut(const []);

      expect(result, TaskResult.rejected);
      verifyInOrder([
        () => mockLogger.warn(
              'package_a@1.2.3 - vuln-id-1: This is a serious issue. '
              '(See https://github.com/advisories/vuln-id-1)',
            ),
        () => mockLogger.warn(
              'package_a@1.2.3 - vuln-id-2: This is another serious issue. '
              '(See https://github.com/advisories/vuln-id-2)',
            ),
        () => mockLogger.warn(
              'package_b@2.0.0 - vuln-id-3: This is a not so serious issue. '
              '(See https://github.com/advisories/vuln-id-3)',
            ),
        () => mockLogger.error('Found 3 security issues in dependencies!')
      ]);

      verifyNoMoreInteractions(mockLogger);
    });
  });
}
