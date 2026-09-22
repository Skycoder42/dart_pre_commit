import 'dart:io';

import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

class FakeFile(@override final String path, {final bool _exists = true})
    extends Fake
    implements File {
  @override
  File get absolute => FakeFile(p.absolute(path), exists: _exists);

  @override
  bool existsSync() => _exists;

  @override
  String resolveSymbolicLinksSync() => path;
}

RepoEntry fakeEntry(
  String path, {
  bool partiallyStaged = false,
  bool exists = true,
}) => RepoEntry(
  file: FakeFile(path, exists: exists),
  partiallyStaged: partiallyStaged,
  gitRoot: Directory.systemTemp,
);
