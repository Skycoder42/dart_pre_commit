import 'dart:io';

import 'package:dart_pre_commit/src/file_resolver.dart';
import 'package:dart_pre_commit/src/logger.dart';
import 'package:dart_pre_commit/src/program_runner.dart';
import 'package:dart_pre_commit/src/pull_up_dependencies.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockFileResolver extends Mock implements FileResolver {}

// ignore: avoid_implementing_value_types
class MockFile extends Mock implements File {}

void main() {
  final mockLogger = MockLogger();
  final mockRunner = MockProgramRunner();
  final mockResolver = MockFileResolver();

  PullUpDependencies sut;

  setUp(() {
    reset(mockLogger);
    reset(mockRunner);
    reset(mockResolver);

    when(mockRunner.run(any, any)).thenAnswer((i) async => 0);

    when(mockResolver.file("pubspec.yaml")).thenAnswer((i) {
      final res = MockFile();
      when(res.readAsString()).thenAnswer((i) async => """
dependencies:
dev_dependencies:
""");
      return res;
    });

    when(mockResolver.file("pubspec.lock")).thenAnswer((i) {
      final res = MockFile();
      when(res.readAsString()).thenAnswer((i) async => """
packages:
""");
      return res;
    });

    sut = PullUpDependencies(
      logger: mockLogger,
      runner: mockRunner,
      fileResolver: mockResolver,
    );
  });

  test("processes packages if lockfile is ignored", () async {
    final result = await sut();
    expect(result, false);

    verify(mockLogger.log("Checking for updates packages..."));
  });

  test("processes packages if lockfile is unstaged", () async {
    when(mockRunner.run(any, any)).thenAnswer((i) async => 1);
    when(mockRunner.stream(any, any))
        .thenAnswer((i) => Stream.fromIterable(const ["pubspec.lock"]));

    final result = await sut();
    expect(result, false);

    verify(mockLogger.log("Checking for updates packages..."));
    verifyNoMoreInteractions(mockLogger);
  });

  test("does nothing if lockfile is tracked but unstaged", () async {
    when(mockRunner.run(any, any)).thenAnswer((i) async => 1);
    when(mockRunner.stream(any, any))
        .thenAnswer((i) => Stream.fromIterable(const []));

    final result = await sut();
    expect(result, false);
    verifyZeroInteractions(mockLogger);
    verifyZeroInteractions(mockResolver);
  });

  test("Finds updates of pulled up versions and returns false", () async {
    when(mockResolver.file("pubspec.yaml")).thenAnswer((i) {
      final res = MockFile();
      when(res.readAsString()).thenAnswer((i) async => """
dependencies:
  a: ^1.0.0
  b: ^1.0.0
dev_dependencies:
  d: ^1.0.0
  e: ^1.0.0
""");
      return res;
    });

    when(mockResolver.file("pubspec.lock")).thenAnswer((i) {
      final res = MockFile();
      when(res.readAsString()).thenAnswer((i) async => """
packages:
  a:
    version: "1.0.0"
  b:
    version: "1.0.1"
  c:
    version: "1.1.0"
  d:
    version: "1.1.0"
  e:
    version: "1.0.0"
  f:
    version: "1.0.1"
""");
      return res;
    });

    final result = await sut();
    expect(result, true);
    verify(mockLogger.log("Checking for updates packages..."));
    verify(mockLogger.log("  b: 1.0.0 -> 1.0.1"));
    verify(mockLogger.log("  d: 1.0.0 -> 1.1.0"));
    verify(
        mockLogger.log("2 dependencies can be pulled up to newer versions!"));
    verifyNoMoreInteractions(mockLogger);
  });

  test("Prints nothing and returns true if no updates match", () async {
    when(mockResolver.file("pubspec.yaml")).thenAnswer((i) {
      final res = MockFile();
      when(res.readAsString()).thenAnswer((i) async => """
dependencies:
  a: ^1.0.0
  b: 1.0.0
dev_dependencies:
  d: 1.0.0
  e: ^1.0.0
""");
      return res;
    });

    when(mockResolver.file("pubspec.lock")).thenAnswer((i) {
      final res = MockFile();
      when(res.readAsString()).thenAnswer((i) async => """
packages:
  a:
    version: "1.0.0"
  b:
    version: "1.0.1"
  c:
    version: "1.1.0"
  d:
    version: "1.1.0"
  e:
    version: "1.0.0"
  f:
    version: "1.0.1"
""");
      return res;
    });

    final result = await sut();
    expect(result, false);
    verify(mockLogger.log("Checking for updates packages..."));
    verifyNoMoreInteractions(mockLogger);
  });
}
