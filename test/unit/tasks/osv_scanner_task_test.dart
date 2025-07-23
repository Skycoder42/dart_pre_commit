// ignore_for_file: unnecessary_lambdas

import 'dart:convert';

import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/models/osv_scanner/osv_scanner_result.dart';
import 'package:dart_pre_commit/src/tasks/models/osv_scanner/package.dart';
import 'package:dart_pre_commit/src/tasks/models/osv_scanner/package_info.dart';
import 'package:dart_pre_commit/src/tasks/models/osv_scanner/result.dart';
import 'package:dart_pre_commit/src/tasks/models/osv_scanner/vulnerability.dart';
import 'package:dart_pre_commit/src/tasks/osv_scanner_task.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/lockfile_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../global_mocks.dart';
import 'flutter_compat_task_test.dart';

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockFileResolver extends Mock implements FileResolver {}

class MockLockfileResolver extends Mock implements LockfileResolver {}

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
    final mockFileResolver = MockFileResolver();
    final mockLockfileResolver = MockLockfileResolver();
    final mockLogger = MockTaskLogger();

    late OsvScannerTask sut;

    setUp(() {
      reset(mockRunner);
      reset(mockFileResolver);
      reset(mockLockfileResolver);
      reset(mockLogger);

      when(
        () => mockRunner.stream(
          any(),
          any(),
          failOnExit: any(named: 'failOnExit'),
        ),
      ).thenAnswer(
        (_) => Stream.value(json.encode(const OsvScannerResult(results: []))),
      );

      when(
        () => mockFileResolver.resolve(any()),
      ).thenAnswer((i) async => i.positionalArguments.first as String);

      when(
        () => mockLockfileResolver.findWorkspaceLockfile(),
      ).thenReturnAsync(FakeFile('pubspec.lock'));

      sut = OsvScannerTask(
        programRunner: mockRunner,
        fileResolver: mockFileResolver,
        lockfileResolver: mockLockfileResolver,
        taskLogger: mockLogger,
        config: const OsvScannerConfig(),
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

    testData<({OsvScannerConfig config, bool hasLockfile, List<String> args})>(
      'runs osv-scanner with correct arguments',
      const [
        (
          config: OsvScannerConfig(),
          hasLockfile: true,
          args: ['scan', '--format', 'json', '--lockfile', 'pubspec.lock'],
        ),
        (
          config: OsvScannerConfig(lockfileOnly: false),
          hasLockfile: true,
          args: [
            'scan',
            '--format',
            'json',
            '--lockfile',
            'pubspec.lock',
            '--recursive',
            '.',
          ],
        ),
        (
          config: OsvScannerConfig(lockfileOnly: false),
          hasLockfile: false,
          args: ['scan', '--format', 'json', '--recursive', '.'],
        ),
        (
          config: OsvScannerConfig(configFile: 'test.toml'),
          hasLockfile: true,
          args: [
            'scan',
            '--format',
            'json',
            '--config',
            'test.toml',
            '--lockfile',
            'pubspec.lock',
          ],
        ),
        (
          config: OsvScannerConfig(
            configFile: 'test.toml',
            lockfileOnly: false,
          ),
          hasLockfile: true,
          args: [
            'scan',
            '--format',
            'json',
            '--config',
            'test.toml',
            '--lockfile',
            'pubspec.lock',
            '--recursive',
            '.',
          ],
        ),
        (
          config: OsvScannerConfig(
            configFile: 'test.toml',
            lockfileOnly: false,
          ),
          hasLockfile: false,
          args: [
            'scan',
            '--format',
            'json',
            '--config',
            'test.toml',
            '--recursive',
            '.',
          ],
        ),
        (
          config: OsvScannerConfig(legacy: true),
          hasLockfile: true,
          args: ['--json', '--lockfile', 'pubspec.lock'],
        ),
      ],
      (fixture) async {
        when(
          () => mockLockfileResolver.findWorkspaceLockfile(),
        ).thenReturnAsync(
          fixture.hasLockfile ? FakeFile('pubspec.lock') : null,
        );

        sut = OsvScannerTask(
          programRunner: mockRunner,
          fileResolver: mockFileResolver,
          lockfileResolver: mockLockfileResolver,
          taskLogger: mockLogger,
          config: fixture.config,
        );

        final result = await sut(const []);

        expect(result, TaskResult.accepted);
        verifyInOrder([
          () => mockLockfileResolver.findWorkspaceLockfile(),
          if (fixture.hasLockfile)
            () => mockFileResolver.resolve('pubspec.lock'),
          () =>
              mockRunner.stream('osv-scanner', fixture.args, failOnExit: false),
        ]);

        verifyNoMoreInteractions(mockRunner);
        verifyNoMoreInteractions(mockFileResolver);
        verifyNoMoreInteractions(mockLockfileResolver);
        verifyZeroInteractions(mockLogger);
      },
    );

    test('throws if lockfile is missing but required', () async {
      when(
        () => mockLockfileResolver.findWorkspaceLockfile(),
      ).thenReturnAsync(null);

      final result = await sut(const []);

      expect(result, TaskResult.rejected);
      verify(() => mockLockfileResolver.findWorkspaceLockfile());
      verifyNever(
        () => mockRunner.stream(
          any(),
          any(),
          failOnExit: any(named: 'failOnExit'),
        ),
      );
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
        () => mockLogger.error('Found 3 security issues in dependencies!'),
      ]);

      verifyNoMoreInteractions(mockLogger);
    });
  });
}
