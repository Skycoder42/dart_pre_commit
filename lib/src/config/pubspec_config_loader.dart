@internal
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import '../util/file_resolver.dart';
import '../util/logger.dart';

part 'pubspec_config_loader.freezed.dart';

/// @nodoc
@internal
@freezed
sealed class PubspecConfig with _$PubspecConfig {
  /// @nodoc
  const factory PubspecConfig({
    @Default(false) bool isFlutterProject,
    @Default(true) bool isPublished,
  }) = _PubspecConfig;
}

/// @nodoc
@internal
@injectable
class PubspecConfigLoader {
  final FileResolver _fileResolver;
  final Logger _logger;

  /// @nodoc
  const PubspecConfigLoader(this._fileResolver, this._logger);

  /// @nodoc
  Future<PubspecConfig> loadPubspecConfig() async {
    final pubspecFile = _fileResolver.file('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      _logger.warn(
        'No pubspec.yaml file found. Skipping pubspec configuration.',
      );
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
