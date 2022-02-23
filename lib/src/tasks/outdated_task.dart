import 'dart:convert';

import '../config/config.dart';
import '../repo_entry.dart';
import '../task_base.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';
import 'models/outdated/outdated_info.dart';

/// The different levels of outdated-ness that can be checked.
enum OutdatedLevel {
  /// Only print recommended updates, do not require any.
  none,

  /// Only require major updates, e.g. 1.X.Y-Z to 2.0.0-0.
  major,

  /// Only require minor updates, e.g. 1.0.X-Y to 1.1.0-0.
  minor,

  /// Only require patch updates, e.g. 1.0.0-X to 1.0.1-0.
  patch,

  /// Require all updates that are available.
  any,
}

/// A task that checks if any of your installed dependencies have to be updated.
///
/// It runs `dart pub outdated` to check on the current status of all packages.
/// If any package can be updated, that update will be printed as a
/// recommendation, but won't reject your commit.
///
/// The [outdatedLevel] however configures, which levels of outdatedness are
/// acceptable. Any updates that at least reach the level are considered
/// mandatory and if available will reject the commit. See [OutdatedLevel] for
/// more details on which versions each level includes.
///
/// {@category tasks}
class OutdatedTask with PatternTaskMixin implements RepoTask {
  /// The [ProgramRunner] instance used by this task.
  final ProgramRunner programRunner;

  /// The [TaskLogger] instance used by this task.
  final TaskLogger logger;

  /// The loaded [Config] for the hooks
  final Config config;

  /// The level of outdatedness that will cause the task to reject the commit.
  final OutdatedLevel outdatedLevel;

  /// Default Constructor.
  const OutdatedTask({
    required this.programRunner,
    required this.logger,
    required this.config,
    required this.outdatedLevel,
  });

  @override
  String get taskName => 'outdated';

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
      switch (outdatedLevel) {
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

      if (hasUpdate && config.allowOutdated.contains(package.package)) {
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
      .map((json) => OutdatedInfo.fromJson(json))
      .single;
}
