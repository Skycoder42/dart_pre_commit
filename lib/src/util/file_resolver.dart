import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:riverpod/riverpod.dart';

// coverage:ignore-start
/// @nodoc
@internal
final fileResolverProvider = Provider((ref) => FileResolver());
// coverage:ignore-end

/// @nodoc
@internal
class FileResolver {
  /// @nodoc
  Future<String> resolve(String path, [Directory? from]) async => relative(
    await File(path).resolveSymbolicLinks(),
    from: await (from ?? Directory.current).resolveSymbolicLinks(),
  );

  /// @nodoc
  Stream<String> resolveAll(Iterable<String> paths, [Directory? from]) =>
      Stream.fromIterable(paths).asyncMap((p) async => resolve(p, from));

  /// @nodoc
  File file(String path) => File(path);
}
