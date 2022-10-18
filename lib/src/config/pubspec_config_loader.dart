import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:riverpod/riverpod.dart';

import '../../dart_pre_commit.dart';

part 'pubspec_config_loader.freezed.dart';

// coverage:ignore-start
final pubspecConfigLoaderProvider = Provider(
  (ref) => PubspecConfigLoader(
    fileResolver: ref.watch(fileResolverProvider),
    logger: ref.watch(loggerProvider),
  ),
);
// coverage:ignore-end

@freezed
class PubspecConfig with _$PubspecConfig {
  const factory PubspecConfig({
    @Default(false) bool isFlutterProject,
    @Default(true) bool isPublished,
  }) = _PubspecConfig;
}

class PubspecConfigLoader {
  final FileResolver fileResolver;
  final Logger logger;

  const PubspecConfigLoader({
    required this.fileResolver,
    required this.logger,
  });

  Future<PubspecConfig> loadPubspecConfig() async {
    final pubspecFile = fileResolver.file('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      logger
          .warn('No pubspec.yaml file found. Skipping pubspec configuration.');
      return const PubspecConfig();
    }

    final pubspecString = await pubspecFile.readAsString();
    final pubspec = Pubspec.parse(pubspecString, sourceUrl: pubspecFile.uri);

    return PubspecConfig(
      isFlutterProject: pubspec.dependencies.containsKey('flutter'),
      isPublished: pubspec.publishTo != 'none',
    );
  }
}
