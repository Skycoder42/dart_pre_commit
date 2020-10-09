import 'dart:io';

import 'package:dart_pre_commit/src/file_resolver.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  Directory testDir;
  final sut = FileResolver();

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp();
  });

  tearDown(() async {
    await testDir.delete(recursive: true);
    testDir = null;
  });

  test("exists checks if file exists", () async {
    await File(join(testDir.path, "test1.dart")).create();

    expect(await sut.exists(join(testDir.path, "test1.dart")), true);
    expect(await sut.exists(join(testDir.path, "test2.dart")), false);
  });

  test("resolve resolves symlinks to a relative path", () async {
    final cwd = Directory.current;
    try {
      Directory.current = testDir;

      final f1 = await File(join(testDir.path, "dir1", "file1.dart")).create(
        recursive: true,
      );
      final l1 = await Link(join(testDir.path, "dir2", "file2.dart")).create(
        f1.path,
        recursive: true,
      );

      final resPath = await sut.resolve(l1.absolute.path);
      expect(resPath, join("dir1", "file1.dart"));
    } finally {
      Directory.current = cwd;
    }
  }, onPlatform: const <String, dynamic>{
    "windows":
        Skip("Creating symbolic links requires admin permission on windows")
  });

  test("resolveAll resolves all symlinks to relative paths", () async {
    final cwd = Directory.current;
    try {
      Directory.current = testDir;

      final f1 = await File(join(testDir.path, "dir1", "file1.dart")).create(
        recursive: true,
      );
      final f2 = await File(join(testDir.path, "dir2", "file2.dart")).create(
        recursive: true,
      );
      final l1 = await Link(join(testDir.path, "dir2", "file1.dart")).create(
        f1.path,
        recursive: true,
      );
      final l2 = await Link(join(testDir.path, "dir1", "file2.dart")).create(
        f2.path,
        recursive: true,
      );

      final resPath = await sut.resolveAll([
        l1.absolute.path,
        l2.absolute.path,
      ]).toList();
      expect(resPath, [
        join("dir1", "file1.dart"),
        join("dir2", "file2.dart"),
      ]);
    } finally {
      Directory.current = cwd;
    }
  }, onPlatform: const <String, dynamic>{
    "windows":
        Skip("Creating symbolic links requires admin permission on windows")
  });
}
