import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/file_resolver.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';

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
/// ```.yaml
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

  /// The [TaskLogger] instance used by this task.
  final TaskLogger logger;

  /// Default Constructor.
  const PullUpDependenciesTask({
    required this.programRunner,
    required this.fileResolver,
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
    final pubspecLock = loadYaml(await lockFile.readAsString()) as YamlMap?;
    final resolvedVersions = _resolveLockVersions(pubspecLock);

    final pubspecFile = fileResolver.file('pubspec.yaml');
    final pubspecYaml = loadYaml(await pubspecFile.readAsString()) as YamlMap?;
    var updateCnt = _pullUpVersions(
      pubspecYaml?['dependencies'] as YamlMap?,
      resolvedVersions,
    );
    updateCnt += _pullUpVersions(
      pubspecYaml?['dev_dependencies'] as YamlMap?,
      resolvedVersions,
    );

    if (updateCnt > 0) {
      logger.info(
        '$updateCnt dependencies can be pulled up to newer versions!',
      );
      return TaskResult.rejected;
    } else {
      logger.debug('All dependencies are up to date');
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

  Map<String, Version> _resolveLockVersions(YamlMap? pubspecLock) {
    final result = <String, Version>{};

    final packages = pubspecLock?['packages'] as YamlMap?;
    if (packages == null) {
      return {};
    }

    for (final package in packages.entries) {
      final name = package.key as String;
      final dependency = package.value as YamlMap?;
      final type = dependency?['dependency'] as String?;
      final version = dependency?['version'] as String?;
      if (version != null && type != null && type != 'transitive') {
        result[name] = Version.parse(version);
      }
    }

    return result;
  }

  int _pullUpVersions(YamlMap? node, Map<String, Version> resolvedVersions) {
    if (node == null) {
      return 0;
    }

    var updateCtr = 0;
    for (final entry in node.entries) {
      if (entry.value is String) {
        final versionString = entry.value as String?;
        if (versionString?.startsWith('^') ?? false) {
          final currentVersion = Version.parse(versionString!.substring(1));
          final resolvedVersion = resolvedVersions[entry.key];
          if (_checkValidRelease(resolvedVersion) &&
              resolvedVersion! > currentVersion) {
            ++updateCtr;
            logger.info('  ${entry.key}: $currentVersion -> $resolvedVersion');
          } else {
            logger.debug(
              '  ${entry.key}: $currentVersion OK',
            );
          }
        } else {
          logger.debug(
            '  ${entry.key}: $versionString skipped',
          );
        }
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
