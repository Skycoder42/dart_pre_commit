import 'dart:io';

import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:mockito/mockito.dart';

class FakeFile extends Fake implements File {
  final bool _exists;

  @override
  final String path;

  @override
  Future<bool> exists() async => _exists;

  FakeFile(this.path, {bool exists = true}) : _exists = exists;
}

class FakeEntry extends RepoEntry {
  FakeEntry(
    String path, {
    bool partiallyStaged = false,
    bool exists = true,
  }) : super(
          file: FakeFile(path, exists: exists),
          partiallyStaged: partiallyStaged,
        );
}
