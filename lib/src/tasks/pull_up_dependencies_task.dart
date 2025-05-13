import 'package:checked_yaml/checked_yaml.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import '../repo_entry.dart';
import '../task_base.dart';
import '../util/file_resolver.dart';
import '../util/lockfile_resolver.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';
import 'models/pull_up_dependencies/pubspec_lock.dart';
import 'provider/task_provider.dart';

part 'pull_up_dependencies_task.freezed.dart';
part 'pull_up_dependencies_task.g.dart';

// coverage:ignore-start
/// A riverpod provider for the pull up dependencies task.
final pullUpDependenciesTaskProvider = TaskProvider.configurable(
  PullUpDependenciesTask._taskName,
  PullUpDependenciesConfig.fromJson,
  (ref, PullUpDependenciesConfig config) => PullUpDependenciesTask(
    fileResolver: ref.watch(fileResolverProvider),
    programRunner: ref.watch(programRunnerProvider),
    lockfileResolver: ref.watch(lockfileResolverProvider),
    logger: ref.watch(taskLoggerProvider),
    config: config,
  ),
);
// coverage:ignore-end

/// @nodoc
@internal
@freezed
sealed class PullUpDependenciesConfig with _$PullUpDependenciesConfig {
  /// @nodoc
  // ignore: invalid_annotation_target
  @JsonSerializable(anyMap: true, checked: true, disallowUnrecognizedKeys: true)
  const factory PullUpDependenciesConfig({
    @Default(<String>[]) List<String> allowed,
  }) = _PullUpDependenciesConfig;

  /// @nodoc
  factory PullUpDependenciesConfig.fromJson(Map<String, dynamic> json) =>
      _$PullUpDependenciesConfigFromJson(json);
}

/// @nodoc
@internal
class PullUpDependenciesTask with PatternTaskMixin implements RepoTask {
  static const _taskName = 'pull-up-dependencies';

  final ProgramRunner _programRunner;

  final FileResolver _fileResolver;

  final LockfileResolver _lockfileResolver;

  final TaskLogger _logger;

  final PullUpDependenciesConfig _config;

  /// @nodoc
  const PullUpDependenciesTask({
    required ProgramRunner programRunner,
    required FileResolver fileResolver,
    required LockfileResolver lockfileResolver,
    required TaskLogger logger,
    required PullUpDependenciesConfig config,
  }) : _programRunner = programRunner,
       _fileResolver = fileResolver,
       _lockfileResolver = lockfileResolver,
       _logger = logger,
       _config = config;

  @override
  String get taskName => _taskName;

  @override
  bool get callForEmptyEntries => true;

  @override
  Pattern get filePattern => 'pubspec.lock';

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    if (!await _shouldCheck(entries)) {
      _logger.debug('No staged changes for pubspec.lock, skipping');
      return TaskResult.accepted;
    }

    final lockFile = await _lockfileResolver.findWorkspaceLockfile();
    if (lockFile == null) {
      return TaskResult.rejected;
    }

    final pubspecLock = checkedYamlDecode(
      await lockFile.readAsString(),
      (yaml) => PubspecLock.fromJson(Map<String, dynamic>.from(yaml!)),
      sourceUrl: lockFile.uri,
    );
    final resolvedVersions = _resolveLockVersions(pubspecLock);

    final pubspecFile = _fileResolver.file('pubspec.yaml');
    final pubspec = Pubspec.parse(
      await pubspecFile.readAsString(),
      sourceUrl: pubspecFile.uri,
    );
    var updateCnt = _pullUpVersions(pubspec.dependencies, resolvedVersions);
    updateCnt += _pullUpVersions(pubspec.devDependencies, resolvedVersions);

    if (updateCnt > 0) {
      _logger.info(
        '=> $updateCnt dependencies can be pulled up to newer versions!',
      );
      return TaskResult.rejected;
    } else {
      _logger.debug('=> All dependencies are up to date');
      return TaskResult.accepted;
    }
  }

  Future<bool> _shouldCheck(Iterable<RepoEntry> entries) async {
    final code = await _programRunner.run('git', const [
      'check-ignore',
      'pubspec.lock',
    ]);

    if (code == 0) {
      // file is ignored
      _logger.debug('pubspec.lock is ignored');
      return true;
    } else {
      // file is not ignored
      _logger.debug('pubspec.lock is not ignored, checking if staged');
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
            if (_config.allowed.contains(entry.key)) {
              _logger.warn(
                '${entry.key}: Ignoring $versionConstraint -> $resolvedVersion',
              );
            } else {
              ++updateCtr;
              _logger.info(
                '${entry.key}: $versionConstraint -> $resolvedVersion',
              );
            }
          } else {
            _logger.debug('${entry.key}: $versionConstraint OK');
          }
        }
      } else {
        _logger.debug('${entry.key}: Skipping non hosted package');
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
