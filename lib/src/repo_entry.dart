import 'dart:io';

/// Describes a file in the repository to be analyzed.
class RepoEntry {
  /// The file in the local file system that this entry represents.
  final File file;

  /// Specifies, whether the file is partially or fully staged.
  final bool partiallyStaged;

  /// Creates a new repo entry.
  const RepoEntry({
    required this.file,
    required this.partiallyStaged,
  });
}
