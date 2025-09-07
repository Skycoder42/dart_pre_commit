import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';

/// @nodoc
@internal
@injectable
class FileResolver {
  /// @nodoc
  Future<String> resolve(String path, [Directory? from]) async => relative(
    await File(path).resolveSymbolicLinks(),
    from: await (from ?? Directory.current).resolveSymbolicLinks(),
  );

  /// @nodoc
  Stream<String> resolveAll(Iterable<String> paths, [Directory? from]) =>
      Stream.fromIterable(paths).asyncMap((p) async => await resolve(p, from));

  /// @nodoc
  File file(String path) => File(path);
}
