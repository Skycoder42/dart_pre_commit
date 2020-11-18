import 'dart:io';

import 'package:dart_pre_commit/src/format.dart';
import 'package:dart_pre_commit/src/program_runner.dart';
import 'package:dart_pre_commit/src/task_exception.dart';
import 'package:mockito/annotations.dart'; // ignore: import_of_legacy_library_into_null_safe
import 'package:mockito/mockito.dart'; // ignore: import_of_legacy_library_into_null_safe
import 'package:test/test.dart';
import 'format_test.mocks.dart';

@GenerateMocks([File, ProgramRunner])
void main() {
  final mockRunner = MockProgramRunner();
  final mockFile = MockFile();

  late Format sut;

  setUp(() {
    reset(mockRunner);
    reset(mockFile);

    when(mockRunner.run(any, any)).thenAnswer((_) async => 0);
    when(mockFile.path).thenReturn('mock.dart');

    sut = Format(mockRunner);
  });

  test('calls dart format with correct arguments', () async {
    final res = await sut(mockFile);
    expect(res, false);
    verify(mockRunner.run(
      'dart',
      const [
        'format',
        '--fix',
        '--set-exit-if-changed',
        'mock.dart',
      ],
    ));
  });

  test('returns true if dart format returns 1', () async {
    when(mockRunner.run(any, any)).thenAnswer((_) async => 1);
    final res = await sut(mockFile);
    expect(res, true);
  });

  test('throws exception if dart format returns >1', () async {
    when(mockRunner.run(any, any)).thenAnswer((_) async => 42);
    expect(() => sut(mockFile), throwsA(isA<TaskException>()));
  });
}
