import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

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

/// Extensions on [OutdatedLevel], that add additional logic to the enum.
extension OutdatedLevelX on OutdatedLevel {
  /// The short name of the value, without the enum class name.
  String get name => toString().split('.').last;

  /// Static method to create a [OutdatedLevel] from the [message].
  ///
  /// The [message] must a a valid outdated level, see [name].
  static OutdatedLevel parse(String message) => OutdatedLevel.values.firstWhere(
        (e) => e.name == message,
        orElse: () => throw ArgumentError.value(message, 'message'),
      );
}

/// An internal base class for [OutdatedTask] and [NullsafeTask].
abstract class OutdatedTaskBase implements RepoTask {
  /// The [ProgramRunner] instance used by this task.
  final ProgramRunner programRunner;

  /// The [TaskLogger] instance used by this task.
  final TaskLogger logger;

  @internal
  const OutdatedTaskBase({
    required this.programRunner,
    required this.logger,
  });

  @override
  bool get callForEmptyEntries => true;

  @override
  Pattern get filePattern => '';

  /// Runs `dart pub outdated` and collects the results.
  ///
  /// The command is run in json mode and the results are parsed to an
  /// [OutdatedInfo] structure. If [nullSafety] is set, the command is run in
  /// null-safety mode instead of outdated mode.
  @protected
  Future<OutdatedInfo> collectOutdated({required bool nullSafety}) =>
      programRunner
          .stream('dart', [
            'pub',
            'outdated',
            '--show-all',
            '--json',
            if (nullSafety) '--mode=null-safety',
          ])
          .transform(json.decoder)
          .cast<Map<String, dynamic>>()
          .map((json) => OutdatedInfo.fromJson(json))
          .single;
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
class OutdatedTask extends OutdatedTaskBase {
  /// The level of outdateness that will cause the task to reject the commit.
  final OutdatedLevel outdatedLevel;

  /// Default Constructor.
  const OutdatedTask({
    required ProgramRunner programRunner,
    required TaskLogger logger,
    required this.outdatedLevel,
  }) : super(
          programRunner: programRunner,
          logger: logger,
        );

  @override
  String get taskName => 'outdated';

  @override
  bool get callForEmptyEntries => true;

  @override
  Pattern get filePattern => '';

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    logger.debug('Checking for outdated packags...');
    final outdated = await collectOutdated(nullSafety: false);

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
      switch (outdatedLevel) {
        case OutdatedLevel.none:
          break;
        case OutdatedLevel.any:
          updated = resolvable > current;
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

      if (updated) {
        ++outdatedCnt;
        logger.info('Required:    ${package.package}: $current -> $resolvable');
      } else if (resolvable > current) {
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
}

/// A task that checks if any of your dependencies can be made nullsafe.
///
/// It runs `dart pub outdated --mode=null-safety` to check on the current
/// status of all packages. If any package has a nullsafe version that has not
/// been installed yet, it shows it as available. Available nullsafety updates
/// will not cause the task to reject your commit..
///
/// However, if any of the nullsafety updates can also be installed without
/// a breaking version update, the package is listed as upgradeable and will
/// cause the task to reject the commit until updated.
///
/// {@category tasks}
class NullsafeTask extends OutdatedTaskBase {
  /// Default Constructor.
  const NullsafeTask({
    required ProgramRunner programRunner,
    required TaskLogger logger,
  }) : super(
          programRunner: programRunner,
          logger: logger,
        );

  @override
  String get taskName => 'nullsafe';

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    logger.debug('Checking for upgradable null-safe packages...');
    final unsafe = await collectOutdated(nullSafety: true);
    var unsafeCnt = 0;
    for (final package in unsafe.packages) {
      final current = package.current;
      final resolvable = package.resolvable;
      final latest = package.latest;

      if (current == null) {
        logger.warn(
          'Skipping:    ${package.package}: No Version information available',
        );
        continue;
      }

      if (current.nullSafety ?? false) {
        logger.debug(
          'Up to date:  ${package.package}: '
          '${current.version} is nullsafe',
        );
        continue;
      }

      if (resolvable?.nullSafety ?? false) {
        ++unsafeCnt;
        logger.info(
          'Upgradeable: ${package.package}: '
          '${current.version} -> ${resolvable!.version}',
        );
        continue;
      }

      if (latest?.nullSafety ?? false) {
        logger.info(
          'Available:   ${package.package}: '
          '${current.version} -> ${latest!.version}',
        );
        continue;
      }

      logger.debug(
        'Skipping:    ${package.package}: No nullsafe version available',
      );
    }

    if (unsafeCnt > 0) {
      logger.info('Found $unsafeCnt upgradeble null-safe package(s)');
      return TaskResult.rejected;
    } else {
      logger.debug('No required nullsafety package updates found');
      return TaskResult.accepted;
    }
  }
}
