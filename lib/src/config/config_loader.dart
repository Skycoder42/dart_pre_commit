import 'dart:io';

import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';
import 'package:yaml/yaml.dart';

import '../util/file_resolver.dart';

// coverage:ignore-start
/// @nodoc
@internal
final configLoaderProvider = Provider(
  (ref) => ConfigLoader(
    fileResolver: ref.watch(fileResolverProvider),
  ),
);
// coverage:ignore-end

/// @nodoc
@internal
class ConfigLoader {
  final FileResolver _fileResolver;

  late YamlMap _globalConfig;

  /// @nodoc
  ConfigLoader({
    required FileResolver fileResolver,
  }) : _fileResolver = fileResolver;

  /// @nodoc
  Future<bool> loadGlobalConfig([File? customConfig]) {
    if (customConfig != null) {
      return _loadCustomConfig(customConfig);
    } else {
      return _loadPubspecConfig();
    }
  }

  /// @nodoc
  YamlMap? loadTaskConfig(String taskName, {bool enabledByDefault = true}) {
    final dynamic taskConfig = _globalConfig[taskName];
    if (taskConfig == null) {
      return enabledByDefault ? YamlMap() : null;
    } else if (taskConfig is bool) {
      return taskConfig ? YamlMap() : null;
    } else if (taskConfig is YamlMap) {
      return taskConfig;
    } else {
      throw Exception(
        'Invalid configuration for $taskName - '
        'value must be null, boolean or a configuration map',
      );
    }
  }

  Future<bool> _loadPubspecConfig() async {
    final configFile = _fileResolver.file('pubspec.yaml');
    final dynamic configYaml = loadYaml(
      await configFile.readAsString(),
      sourceUrl: configFile.uri,
    );

    return _parseConfig(
      'dart_pre_commit',
      (configYaml as YamlMap)['dart_pre_commit'],
    );
  }

  Future<bool> _loadCustomConfig(File customConfig) async {
    final dynamic configYaml = loadYaml(
      await customConfig.readAsString(),
      sourceUrl: customConfig.uri,
    );

    return _parseConfig(customConfig.path, configYaml);
  }

  bool _parseConfig(String name, dynamic config) {
    if (config == null) {
      _globalConfig = YamlMap();
      return true;
    } else if (config is bool) {
      _globalConfig = YamlMap();
      return config;
    } else if (config is YamlMap) {
      _globalConfig = config;
      return true;
    } else {
      throw Exception('$name must be null, a boolean or a configuration map');
    }
  }

  /// @nodoc
  @visibleForTesting
  YamlMap get debugGlobalConfig => _globalConfig;
}
