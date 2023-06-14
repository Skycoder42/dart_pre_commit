import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';
import 'models/osv_scanner/osv_scanner_result.dart';
import 'models/osv_scanner/package_info.dart';
import 'models/osv_scanner/vulnerability.dart';
import 'provider/task_provider.dart';

part 'osv_scanner_task.freezed.dart';
part 'osv_scanner_task.g.dart';

// coverage:ignore-start
/// A riverpod provider for the osv scanner task.
final osvScannerTaskProvider = TaskProvider.configurable(
  OsvScannerTask._taskName,
  OsvScannerConfig.fromJson,
  (ref, config) => OsvScannerTask(
    programRunner: ref.watch(programRunnerProvider),
    taskLogger: ref.watch(taskLoggerProvider),
    config: config,
  ),
);
// coverage:ignore-end

/// @nodoc
@internal
@freezed
class OsvScannerConfig with _$OsvScannerConfig {
  /// @nodoc
  // ignore: invalid_annotation_target
  @JsonSerializable(
    anyMap: true,
    checked: true,
    disallowUnrecognizedKeys: true,
  )
  const factory OsvScannerConfig({
    // ignore: invalid_annotation_target
    @JsonKey(name: 'lockfile-only') @Default(true) bool lockfileOnly,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'config') String? configFile,
  }) = _OsvScannerConfig;

  /// @nodoc
  factory OsvScannerConfig.fromJson(Map<String, dynamic> json) =>
      _$OsvScannerConfigFromJson(json);
}

/// @nodoc
@internal
class OsvScannerTask implements RepoTask {
  static const _taskName = 'osv-scanner';

  /// @nodoc
  static const osvScannerBinary = 'osv-scanner';

  final ProgramRunner _programRunner;
  final TaskLogger _taskLogger;
  final OsvScannerConfig _config;

  /// @nodoc
  const OsvScannerTask({
    required ProgramRunner programRunner,
    required TaskLogger taskLogger,
    required OsvScannerConfig config,
  })  : _programRunner = programRunner,
        _taskLogger = taskLogger,
        _config = config;

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
          [
            '--json',
            ...switch (_config.configFile) {
              final String path => ['--config', path],
              _ => [],
            },
            '--lockfile',
            'pubspec.lock',
            if (!_config.lockfileOnly) ...[
              '--recursive',
              '.',
            ],
          ],
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
