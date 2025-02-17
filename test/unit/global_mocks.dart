import 'dart:io';

import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

class FakeFile extends Fake implements File {
  final bool _exists;

  @override
  final String path;

  @override
  File get absolute => FakeFile(p.absolute(path), exists: _exists);

  @override
  bool existsSync() => _exists;

  @override
  String resolveSymbolicLinksSync() => path;

  FakeFile(this.path, {bool exists = true}) : _exists = exists;
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
