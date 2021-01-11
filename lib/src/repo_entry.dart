import 'dart:io';

class RepoEntry {
  final File file;
  final bool partiallyStaged;

  const RepoEntry({
    required this.file,
    required this.partiallyStaged,
  });
}
