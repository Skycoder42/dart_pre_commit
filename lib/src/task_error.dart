import 'dart:io';

class TaskError {
  final String message;
  final File file;

  const TaskError(this.message, [this.file]);

  @override
  String toString() => file != null ? "${file.path}: $message" : message;
}
