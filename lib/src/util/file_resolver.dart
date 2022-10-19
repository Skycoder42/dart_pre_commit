import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:riverpod/riverpod.dart';

// coverage:ignore-start
@internal
final fileResolverProvider = Provider(
  (ref) => FileResolver(),
);
// coverage:ignore-end

@internal
class FileResolver {
  Future<String> resolve(String path, [Directory? from]) async => relative(
        await File(path).resolveSymbolicLinks(),
        from: await (from ?? Directory.current).resolveSymbolicLinks(),
      );

  Stream<String> resolveAll(Iterable<String> paths, [Directory? from]) =>
      Stream.fromIterable(paths).asyncMap((p) async => resolve(p, from));

  File file(String path) => File(path);
}
