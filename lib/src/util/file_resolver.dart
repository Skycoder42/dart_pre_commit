import 'dart:io';

import 'package:path/path.dart';

/// Helper class to resolve file paths
class FileResolver {
  /// Finds the conanical relative path of [path], relative to [from]
  ///
  /// Unlike the standard paths methods, this also relsoves symlinks etc.
  ///
  /// If [from] is not specified, [Directory.current] is used.
  Future<String> resolve(String path, [Directory? from]) async => relative(
        await File(path).resolveSymbolicLinks(),
        from: await (from ?? Directory.current).resolveSymbolicLinks(),
      );

  /// Finds the conanical relative paths of all [paths], relative to [from]
  ///
  /// Unlike the standard paths methods, this also relsoves symlinks etc.
  ///
  /// If [from] is not specified, [Directory.current] is used.
  Stream<String> resolveAll(Iterable<String> paths, [Directory? from]) =>
      Stream.fromIterable(paths).asyncMap((p) => resolve(p, from));

  /// Create a new [File] instance.
  ///
  /// This is a basic wrapper, for testability.
  File file(String path) => File(path);
}
