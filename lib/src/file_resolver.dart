import 'dart:io';

import 'package:path/path.dart';

class FileResolver {
  Future<bool> exists(String path) => File(path).exists();

  Future<String> resolve(String path) async => relative(
        await File(path).resolveSymbolicLinks(),
        from: await Directory.current.resolveSymbolicLinks(),
      );

  Stream<String> resolveAll(Iterable<String> paths) =>
      Stream.fromIterable(paths).asyncMap(resolve);
}
