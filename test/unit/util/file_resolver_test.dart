import 'dart:io';

import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  late Directory testDir;
  final sut = FileResolver();

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp();
  });

  tearDown(() async {
    await testDir.delete(recursive: true);
  });

  test(
    'resolve resolves symlinks to a relative path',
    () async {
      final f1 = await File(
        join(testDir.path, 'dir1', 'file1.dart'),
      ).create(recursive: true);
      final l1 = await Link(
        join(testDir.path, 'dir2', 'file2.dart'),
      ).create(f1.path, recursive: true);

      final resPath = await sut.resolve(l1.absolute.path, testDir);
      expect(resPath, join('dir1', 'file1.dart'));
    },
    onPlatform: const <String, dynamic>{
      'windows': Skip(
        'Creating symbolic links requires admin permission on windows',
      ),
    },
  );

  test(
    'resolveAll resolves all symlinks to relative paths',
    () async {
      final f1 = await File(
        join(testDir.path, 'dir1', 'file1.dart'),
      ).create(recursive: true);
      final f2 = await File(
        join(testDir.path, 'dir2', 'file2.dart'),
      ).create(recursive: true);
      final l1 = await Link(
        join(testDir.path, 'dir2', 'file1.dart'),
      ).create(f1.path, recursive: true);
      final l2 = await Link(
        join(testDir.path, 'dir1', 'file2.dart'),
      ).create(f2.path, recursive: true);

      final resPath = await sut.resolveAll([
        l1.absolute.path,
        l2.absolute.path,
      ], testDir).toList();
      expect(resPath, [join('dir1', 'file1.dart'), join('dir2', 'file2.dart')]);
    },
    onPlatform: const <String, dynamic>{
      'windows': Skip(
        'Creating symbolic links requires admin permission on windows',
      ),
    },
  );

  test('file creates file object', () {
    final file = sut.file('test/path.ext');
    expect(file.path, 'test/path.ext');
  });
}
