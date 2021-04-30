import 'dart:io';

import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:mocktail/mocktail.dart';

class FakeFile extends Fake implements File {
  final bool _exists;

  @override
  final String path;

  @override
  Future<bool> exists() async => _exists;

  FakeFile(this.path, {bool exists = true}) : _exists = exists;
}

class FakeEntry extends Fake implements RepoEntry {
  @override
  final FakeFile file;

  @override
  final bool partiallyStaged;

  FakeEntry(
    String path, {
    this.partiallyStaged = false,
    bool exists = true,
  }) : file = FakeFile(path, exists: exists);
}
