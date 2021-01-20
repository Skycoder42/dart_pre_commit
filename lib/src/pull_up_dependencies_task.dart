import 'package:pub_semver/pub_semver.dart'; // ignore: import_of_legacy_library_into_null_safe
import 'package:yaml/yaml.dart';

import 'file_resolver.dart';
import 'logger.dart';
import 'program_runner.dart';
import 'repo_entry.dart';
import 'task_base.dart';

class PullUpDependenciesTask implements RepoTask {
  final ProgramRunner programRunner;
  final FileResolver fileResolver;
  final TaskLogger logger;

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
      return TaskResult.accepted;
    }

    logger.debug('Checking for updated packages...');
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
      return true;
    } else {
      // file is not ignored
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
          }
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