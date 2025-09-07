import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import '../util/file_resolver.dart';

/// @nodoc
@internal
@singleton
class ConfigLoader {
  static const _excludedFilesKey = 'exclude';

  final FileResolver _fileResolver;

  late YamlMap _globalConfig;

  /// @nodoc
  ConfigLoader(this._fileResolver);

  /// @nodoc
  Future<bool> loadGlobalConfig([File? customConfig]) {
    if (customConfig != null) {
      return _loadCustomConfig(customConfig);
    } else {
      return _loadPubspecConfig();
    }
  }

  List<RegExp> loadExcludePatterns() {
    final excludedFiles = _globalConfig[_excludedFilesKey];
    return switch (excludedFiles) {
      null => const [],
      String() => [RegExp(excludedFiles)],
      YamlList() => excludedFiles.cast<String>().map(RegExp.new).toList(),
      _ => throw Exception(
        'Invalid configuration for $_excludedFilesKey - '
        'value must be null, string or a list of strings',
      ),
    };
  }

  /// @nodoc
  YamlMap? loadTaskConfig(String taskName, {bool enabledByDefault = true}) {
    final dynamic taskConfig = _globalConfig[taskName];
    switch (taskConfig) {
      case null when enabledByDefault:
      case true:
        return YamlMap();
      case null:
      case false:
        return null;
      case YamlMap():
        return taskConfig;
      default:
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
    switch (config) {
      case null || true:
        _globalConfig = YamlMap();
        return true;
      case false:
        _globalConfig = YamlMap();
        return false;
      case YamlMap():
        _globalConfig = config;
        return true;
      default:
        throw Exception('$name must be null, a boolean or a configuration map');
    }
  }

  /// @nodoc
  @visibleForTesting
  YamlMap get debugGlobalConfig => _globalConfig;
}
