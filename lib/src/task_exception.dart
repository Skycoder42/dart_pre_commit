import 'dart:io';

class TaskException implements Exception {
  final String message;
  final File? file;

  const TaskException(this.message, [this.file]);

  @override
  String toString() =>
      file != null ? '${file?.path ?? 'unknown'}: $message' : message;
}
