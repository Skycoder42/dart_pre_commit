import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'repo_entry.freezed.dart';

/// Describes a file in the repository to be analyzed.
@freezed
class RepoEntry with _$RepoEntry {
  /// Creates a new repo entry.
  const factory RepoEntry({
    /// The file in the local file system that this entry represents.
    required File file,

    /// Specifies, whether the file is partially or fully staged.
    required bool partiallyStaged,
  }) = _RepoEntry;
}
