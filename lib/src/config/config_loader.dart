import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart';

import '../util/file_resolver.dart';
import 'config.dart';
import 'pubspec_stub.dart';

class ConfigLoader {
  final FileResolver fileResolver;

  const ConfigLoader({
    required this.fileResolver,
  });

  Future<Config> loadConfig([File? pubspecFile]) async {
    final configFile = pubspecFile ?? fileResolver.file('pubspec.yaml');
    final configYaml = await configFile.readAsString();
    final pubspec = checkedYamlDecode(
      configYaml,
      (yaml) => PubspecStub.fromJson(Map<String, dynamic>.from(yaml!)),
      sourceUrl: configFile.uri,
      allowNull: false,
    );
    return pubspec.dartPreCommit;
  }
}
