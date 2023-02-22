import 'dart:convert';

import 'package:meta/meta.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';
import 'models/osv_scanner/osv_scanner_result.dart';
import 'models/osv_scanner/package_info.dart';
import 'models/osv_scanner/vulnerability.dart';
import 'provider/task_provider.dart';

// coverage:ignore-start
/// A riverpod provider for the osv scanner task.
final osvScannerTaskProvider = TaskProvider(
  OsvScannerTask._taskName,
  (ref) => OsvScannerTask(
    programRunner: ref.watch(programRunnerProvider),
    taskLogger: ref.watch(taskLoggerProvider),
  ),
);
// coverage:ignore-end

/// @nodoc
@internal
class OsvScannerTask implements RepoTask {
  static const _taskName = 'osv-scanner';

  /// @nodoc
  static const osvScannerBinary = 'osv-scanner';

  final ProgramRunner _programRunner;
  final TaskLogger _taskLogger;

  /// @nodoc
  const OsvScannerTask({
    required ProgramRunner programRunner,
    required TaskLogger taskLogger,
  })  : _programRunner = programRunner,
        _taskLogger = taskLogger;

  @override
  String get taskName => _taskName;

  @override
  bool canProcess(RepoEntry entry) => false;

  @override
  bool get callForEmptyEntries => true;

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    final osvScannerJson = await _programRunner
        .stream(
          osvScannerBinary,
          const ['--lockfile', 'pubspec.lock', '--json'],
          failOnExit: false,
        )
        .transform(json.decoder)
        .cast<Map<String, dynamic>>()
        .map(OsvScannerResult.fromJson)
        .single;

    var vulnerabilityCount = 0;
    for (final result in osvScannerJson.results) {
      for (final package in result.packages) {
        for (final vulnerability in package.vulnerabilities) {
          ++vulnerabilityCount;
          _logVulnerability(package.package, vulnerability);
        }
      }
    }

    if (vulnerabilityCount > 0) {
      _taskLogger.error(
        'Found $vulnerabilityCount security issues in dependencies!',
      );
      return TaskResult.rejected;
    } else {
      return TaskResult.accepted;
    }
  }

  void _logVulnerability(
    PackageInfo package,
    Vulnerability vulnerability,
  ) {
    _taskLogger.warn(
      '${package.name}@${package.version} - '
      '${vulnerability.id}: ${vulnerability.summary}. '
      '(See https://github.com/advisories/${vulnerability.id})',
    );
  }
}
