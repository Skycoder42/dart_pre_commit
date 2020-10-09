import 'dart:io';

import 'package:path/path.dart';

class FileResolver {
  Future<bool> exists(String path) => File(path).exists();

  Future<String> resolve(String path, [Directory from]) async => relative(
        await File(path).resolveSymbolicLinks(),
        from: await (from ?? Directory.current).resolveSymbolicLinks(),
      );

  Stream<String> resolveAll(Iterable<String> paths, [Directory from]) =>
      Stream.fromIterable(paths).asyncMap((p) => resolve(p, from));
}
