import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';
import 'models/outdated/outdated_info.dart';
import 'provider/task_provider.dart';

part 'outdated_task.freezed.dart';
part 'outdated_task.g.dart';

// coverage:ignore-start
final outdatedTaskProvider = TaskProvider.configurable(
  OutdatedTask._taskName,
  OutdatedConfig.fromJson,
  (ref, OutdatedConfig config) => OutdatedTask(
    programRunner: ref.watch(programRunnerProvider),
    logger: ref.watch(taskLoggerProvider),
    config: config,
  ),
);
// coverage:ignore-end

@internal
enum OutdatedLevel {
  none,
  major,
  minor,
  patch,
  any,
}

@internal
@freezed
class OutdatedConfig with _$OutdatedConfig {
  // ignore: invalid_annotation_target
  @JsonSerializable(
    anyMap: true,
    checked: true,
    disallowUnrecognizedKeys: true,
  )
  const factory OutdatedConfig({
    @Default(OutdatedLevel.any) OutdatedLevel level,
    @Default(<String>[]) List<String> allowed,
  }) = _OutdatedConfig;

  factory OutdatedConfig.fromJson(Map<String, dynamic> json) =>
      _$OutdatedConfigFromJson(json);
}

@internal
class OutdatedTask with PatternTaskMixin implements RepoTask {
  static const _taskName = 'outdated';

  final ProgramRunner programRunner;

  final TaskLogger logger;

  final OutdatedConfig config;

  const OutdatedTask({
    required this.programRunner,
    required this.logger,
    required this.config,
  });

  @override
  String get taskName => _taskName;

  @override
  bool get callForEmptyEntries => true;

  @override
  Pattern get filePattern => '';

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    logger.debug('Checking for outdated packages...');
    final outdated = await _collectOutdated();

    var outdatedCnt = 0;
    for (final package in outdated.packages) {
      final current = package.current?.version;
      final resolvable = package.resolvable?.version;
      if (current == null || resolvable == null) {
        logger.warn(
          'Skipping:    ${package.package}: No Version information available',
        );
        continue;
      }

      var updated = false;
      final hasUpdate = resolvable > current;
      switch (config.level) {
        case OutdatedLevel.none:
          break;
        case OutdatedLevel.any:
          updated = hasUpdate;
          break;
        case OutdatedLevel.patch:
          updated = updated || resolvable.patch > current.patch;
          continue minor;
        minor:
        case OutdatedLevel.minor:
          updated = updated || resolvable.minor > current.minor;
          continue major;
        major:
        case OutdatedLevel.major:
          updated = updated || resolvable.major > current.major;
          break;
      }

      if (hasUpdate && config.allowed.contains(package.package)) {
        logger.warn('Ignored:     ${package.package}: $current -> $resolvable');
      } else if (updated) {
        ++outdatedCnt;
        logger.info('Required:    ${package.package}: $current -> $resolvable');
      } else if (hasUpdate) {
        logger.info('Recommended: ${package.package}: $current -> $resolvable');
      } else {
        logger.debug('Up to date:  ${package.package}: $current');
      }
    }

    if (outdatedCnt > 0) {
      logger.info(
        'Found $outdatedCnt outdated package(s) that have to be updated',
      );
      return TaskResult.rejected;
    } else {
      logger.debug('No required package updates found');
      return TaskResult.accepted;
    }
  }

  Future<OutdatedInfo> _collectOutdated() => programRunner
      .stream('dart', [
        'pub',
        'outdated',
        '--show-all',
        '--json',
      ])
      .transform(json.decoder)
      .cast<Map<String, dynamic>>()
      .map(OutdatedInfo.fromJson)
      .single;
}
