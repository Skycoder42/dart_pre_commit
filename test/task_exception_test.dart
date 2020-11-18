import 'dart:io';

import 'package:dart_pre_commit/src/task_exception.dart';
import 'package:test/test.dart';

void main() {
  test('correctly formats error without file', () {
    const error = TaskException('test');
    expect(error.toString(), 'test');
  });

  test('correctly formats error without file', () {
    final error = TaskException('test', File('pubspec.yaml'));
    expect(error.toString(), 'pubspec.yaml: test');
  });
}
