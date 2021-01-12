import 'package:dart_pre_commit/src/task_exception.dart';
import 'package:test/test.dart';

import 'global_mocks.dart';

void main() {
  test('correctly formats error without entry', () {
    const error = TaskException('test');
    expect(error.toString(), 'test');
  });

  test('correctly formats error with entry', () {
    final error = TaskException('test', FakeEntry('pubspec.yaml'));
    expect(error.toString(), 'pubspec.yaml: test');
  });
}
