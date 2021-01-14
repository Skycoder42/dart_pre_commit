import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:dart_pre_commit/src/task_exception.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'global_mocks.dart';
import 'task_exception_test.mocks.dart';

@GenerateMocks([
  TaskBase,
])
void main() {
  final mockTaskBase = MockTaskBase();

  setUp(() {
    when(mockTaskBase.taskName).thenReturn('task');
  });

  test('correctly formats error without scope', () {
    final error = TaskException('test');
    expect(error.toString(), 'test');
  });

  test('correctly formats error with scope (task only)', () {
    final scope = TaskExceptionScope(mockTaskBase);
    final error = TaskException('test');
    expect(error.toString(), '[task] test');
    scope.dispose();
  });

  test('correctly formats error with scope (task and entry)', () {
    final entry = FakeEntry('path/name.ext');
    final scope = TaskExceptionScope(mockTaskBase, entry);
    final error = TaskException('test');
    expect(error.toString(), 'path/name.ext: [task] test');
    scope.dispose();
  });
}
