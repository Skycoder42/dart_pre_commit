import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:riverpod/riverpod.dart';

import '../util/file_resolver.dart';
import '../util/logger.dart';

part 'pubspec_config_loader.freezed.dart';

// coverage:ignore-start
/// @nodoc
@internal
final pubspecConfigLoaderProvider = Provider(
  (ref) => PubspecConfigLoader(
    fileResolver: ref.watch(fileResolverProvider),
    logger: ref.watch(loggerProvider),
  ),
);
// coverage:ignore-end

/// @nodoc
@internal
@freezed
class PubspecConfig with _$PubspecConfig {
  /// @nodoc
  const factory PubspecConfig({
    @Default(false) bool isFlutterProject,
    @Default(true) bool isPublished,
    @Default(false) bool hasCustomLintDependency,
  }) = _PubspecConfig;
}

/// @nodoc
@internal
class PubspecConfigLoader {
  final FileResolver _fileResolver;
  final Logger _logger;

  /// @nodoc
  const PubspecConfigLoader({
    required FileResolver fileResolver,
    required Logger logger,
  })  : _fileResolver = fileResolver,
        _logger = logger;

  /// @nodoc
  Future<PubspecConfig> loadPubspecConfig() async {
    final pubspecFile = _fileResolver.file('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      _logger
          .warn('No pubspec.yaml file found. Skipping pubspec configuration.');
      return const PubspecConfig();
    }

    final pubspecString = await pubspecFile.readAsString();
    final pubspec = Pubspec.parse(pubspecString, sourceUrl: pubspecFile.uri);

    return PubspecConfig(
      isFlutterProject: pubspec.dependencies.containsKey('flutter'),
      isPublished: pubspec.publishTo != 'none',
      hasCustomLintDependency:
          pubspec.devDependencies.containsKey('custom_lint'),
    );
  }
}
