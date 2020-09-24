import 'dart:io';

import 'package:dart_lint_hooks/src/task_error.dart';
import 'package:test/test.dart';

void main() {
  test("correctly formats error without file", () {
    const error = TaskError("test");
    expect(error.toString(), "test");
  });

  test("correctly formats error without file", () {
    final error = TaskError("test", File("pubspec.yaml"));
    expect(error.toString(), "pubspec.yaml: test");
  });
}
