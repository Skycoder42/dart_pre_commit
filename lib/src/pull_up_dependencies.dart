import 'package:pub_semver/pub_semver.dart'; // ignore: import_of_legacy_library_into_null_safe
import 'package:yaml/yaml.dart'; // ignore: import_of_legacy_library_into_null_safe

import 'file_resolver.dart';
import 'logger.dart';
import 'program_runner.dart';

class PullUpDependencies {
  final Logger logger;
  final ProgramRunner runner;
  final FileResolver fileResolver;

  const PullUpDependencies({
    required this.logger,
    required this.runner,
    required this.fileResolver,
  });

  Future<bool> call() async {
    if (!await _shouldCheck()) {
      return false;
    }

    logger.log('Checking for updates packages...');
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
      logger.log('$updateCnt dependencies can be pulled up to newer versions!');
      return true;
    } else {
      return false;
    }
  }

  Future<bool> _shouldCheck() async {
    final code = await runner.run('git', const [
      'check-ignore',
      'pubspec.lock',
    ]);

    if (code == 0) {
      // file is ignored
      return true;
    } else {
      // file is not ignored
      return runner.stream('git', const [
        'diff',
        '--name-only',
        '--cached',
      ]).contains('pubspec.lock');
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
          if (resolvedVersion != null &&
              resolvedVersion > currentVersion &&
              !resolvedVersion.isPreRelease) {
            ++updateCtr;
            logger.log('  ${entry.key}: $currentVersion -> $resolvedVersion');
          }
        }
      }
    }
    return updateCtr;
  }
}
