import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart';
import 'package:riverpod/riverpod.dart';

import '../util/file_resolver.dart';
import 'config.dart';
import 'pubspec_stub.dart';

final configFilePathProvider = Provider<File?>(
  (ref) => throw UnimplementedError(),
);

final configLoaderProvider = Provider(
  (ref) => ConfigLoader(
    fileResolver: ref.watch(fileResolverProvider),
  ),
);

final configProvider = FutureProvider<Config>(
  (ref) => ref
      .watch(configLoaderProvider)
      .loadConfig(ref.watch(configFilePathProvider)),
);

/// A helper class that extracts the [Config] for the pre commit hooks from
/// the pubspec.yaml or any other yaml file.
class ConfigLoader {
  /// The [FileResolver] instance used by the loader.
  final FileResolver fileResolver;

  /// Default constructor
  const ConfigLoader({
    required this.fileResolver,
  });

  /// Loads the [Config] from the given [pubspecFile]. If none is specified,
  /// the default `pubspec.yaml` in the current directory is used.
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
