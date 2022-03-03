import 'package:checked_yaml/checked_yaml.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import '../config/config.dart';
import '../repo_entry.dart';
import '../task_base.dart';
import '../util/file_resolver.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';
import 'models/pull_up_dependencies/pubspec_lock.dart';

/// This task scans the lockfile to check if dependencies should be pulled up.
///
/// Pulling up means, that the `pubspec.yaml` and `pubspec.lock` are scanned to
/// check if any dependencies in the lockfile have a higher version then
/// specified in the `pubspec.yaml`. If that is the case, the task will print
/// out the dependencies as well as the version it should be pulled up to and
/// exit with [TaskResult.rejected].
///
/// The task only checks for normal versions and ignores prereleases etc.
/// However, it does include nullsafe versions.
///
/// If the lockfile is checked in, this task only runs whenever the lockfile has
/// actually been staged. If it is ignored, the task instead runs on every
/// commit to find dependencies.
///
/// Example:
/// ```yaml
/// # pubspec.yaml
/// dependencies:
///   dep_a: ^1.0.0
///   dep_b: ^2.0.0
///
/// # pubspec.lock
/// dep_a:
///   version: 1.0.0
/// dep_b:
///   version: 1.1.0
/// ```
/// In this example, the task would report `dep_b`, as the actually used version
/// in the lockfile is higher then the minimal allowed version in the project.
///
/// {@category tasks}
class PullUpDependenciesTask with PatternTaskMixin implements RepoTask {
  /// The [ProgramRunner] instance used by this task.
  final ProgramRunner programRunner;

  /// The [FileResolver] instance used by this task.
  final FileResolver fileResolver;

  /// The loaded [Config] for the hooks
  final Config config;

  /// The [TaskLogger] instance used by this task.
  final TaskLogger logger;

  /// Default Constructor.
  const PullUpDependenciesTask({
    required this.programRunner,
    required this.fileResolver,
    required this.config,
    required this.logger,
  });

  @override
  String get taskName => 'pull-up-dependencies';

  @override
  bool get callForEmptyEntries => true;

  @override
  Pattern get filePattern => 'pubspec.lock';

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    if (!await _shouldCheck(entries)) {
      logger.debug('No staged changes for pubspec.lock, skipping');
      return TaskResult.accepted;
    }

    final lockFile = fileResolver.file('pubspec.lock');
    final pubspecLock = checkedYamlDecode(
      await lockFile.readAsString(),
      (yaml) => PubspecLock.fromJson(Map<String, dynamic>.from(yaml!)),
      sourceUrl: lockFile.uri,
      allowNull: false,
    );
    final resolvedVersions = _resolveLockVersions(pubspecLock);

    final pubspecFile = fileResolver.file('pubspec.yaml');
    final pubspec = Pubspec.parse(
      await pubspecFile.readAsString(),
      sourceUrl: pubspecFile.uri,
    );
    var updateCnt = _pullUpVersions(
      pubspec.dependencies,
      resolvedVersions,
    );
    updateCnt += _pullUpVersions(
      pubspec.devDependencies,
      resolvedVersions,
    );

    if (updateCnt > 0) {
      logger.info(
        '=> $updateCnt dependencies can be pulled up to newer versions!',
      );
      return TaskResult.rejected;
    } else {
      logger.debug('=> All dependencies are up to date');
      return TaskResult.accepted;
    }
  }

  Future<bool> _shouldCheck(Iterable<RepoEntry> entries) async {
    final code = await programRunner.run('git', const [
      'check-ignore',
      'pubspec.lock',
    ]);

    if (code == 0) {
      // file is ignored
      logger.debug('pubspec.lock is ignored');
      return true;
    } else {
      // file is not ignored
      logger.debug('pubspec.lock is not ignored, checking if staged');
      return entries.isNotEmpty;
    }
  }

  Map<String, Version> _resolveLockVersions(PubspecLock pubspecLock) {
    final result = <String, Version>{};

    for (final package in pubspecLock.packages.entries) {
      if (package.value.dependency != 'transitive') {
        result[package.key] = package.value.version;
      }
    }

    return result;
  }

  int _pullUpVersions(
    Map<String, Dependency> node,
    Map<String, Version> resolvedVersions,
  ) {
    var updateCtr = 0;
    for (final entry in node.entries) {
      final dependency = entry.value;
      if (dependency is HostedDependency) {
        final versionConstraint = dependency.version;
        if (versionConstraint is VersionRange) {
          final resolvedVersion = resolvedVersions[entry.key];
          final minVersion = versionConstraint.min;
          if (_checkValidRelease(resolvedVersion) &&
              minVersion != null &&
              resolvedVersion! > minVersion) {
            if (config.allowOutdated.contains(entry.key)) {
              logger.warn(
                '${entry.key}: Ignoring $versionConstraint -> $resolvedVersion',
              );
            } else {
              ++updateCtr;
              logger
                  .info('${entry.key}: $versionConstraint -> $resolvedVersion');
            }
          } else {
            logger.debug('${entry.key}: $versionConstraint OK');
          }
        }
      } else {
        logger.debug('${entry.key}: Skipping non hosted package');
      }
    }
    return updateCtr;
  }

  bool _checkValidRelease(Version? version) {
    if (version == null) {
      return false;
    }
    if (!version.isPreRelease) {
      return true;
    }
    return version.preRelease.isNotEmpty &&
        version.preRelease[0] == 'nullsafety';
  }
}
