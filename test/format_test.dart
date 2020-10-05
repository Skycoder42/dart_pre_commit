import 'dart:io';

import 'package:dart_pre_commit/src/format.dart';
import 'package:dart_pre_commit/src/program_runner.dart';
import 'package:dart_pre_commit/src/task_error.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockFile extends Mock implements File {}

class MockRunner extends Mock implements ProgramRunner {}

void main() {
  final mockRunner = MockRunner();
  final mockFile = MockFile();

  Format sut;

  setUp(() {
    reset(mockRunner);
    reset(mockFile);

    when(mockRunner.run(any, any)).thenAnswer((_) async => 0);
    when(mockFile.path).thenReturn("mock.dart");

    sut = Format(mockRunner);
  });

  test("calls dart format with correct arguments", () async {
    final res = await sut(mockFile);
    expect(res, false);
    verify(mockRunner.run(
      "dart",
      const [
        "format",
        "--fix",
        "--set-exit-if-changed",
        "mock.dart",
      ],
    ));
  });

  test("returns true if dart format returns 1", () async {
    when(mockRunner.run(any, any)).thenAnswer((_) async => 1);
    final res = await sut(mockFile);
    expect(res, true);
  });

  test("throws exception if dart format returns >1", () async {
    when(mockRunner.run(any, any)).thenAnswer((_) async => 42);
    expect(() => sut(mockFile), throwsA(isA<TaskError>()));
  });
}
