import 'dart:io';

import 'package:dart_pre_commit/src/config/config_loader.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockFileResolver extends Mock implements FileResolver {}

class MockFile extends Mock implements File {}

void main() {
  group('ConfigLoader', () {
    final testUri = Uri.file('pubspec.yaml');

    final mockFileResolver = MockFileResolver();
    final mockFile = MockFile();

    late ConfigLoader sut;

    setUp(() {
      reset(mockFileResolver);
      reset(mockFile);

      when(() => mockFileResolver.file(any())).thenReturn(mockFile);
      when(() => mockFile.uri).thenReturn(testUri);

      sut = ConfigLoader(fileResolver: mockFileResolver);
    });

    test('load config uses pubspec.yaml by default', () async {
      when(() => mockFile.readAsString()).thenAnswer((i) async => 'name: test');

      await sut.loadConfig();

      verifyInOrder([
        () => mockFileResolver.file('pubspec.yaml'),
        () => mockFile.readAsString(),
      ]);
    });

    test('load uses given file', () async {
      when(() => mockFile.readAsString()).thenAnswer((i) async => 'name: test');

      await sut.loadConfig(mockFile);

      verifyZeroInteractions(mockFileResolver);
      verify(() => mockFile.readAsString());
    });

    test('Uses defaults for missing config', () async {
      when(() => mockFile.readAsString()).thenAnswer(
        (i) async => '''
name: test
dart_pre_commit: null
''',
      );

      final config = await sut.loadConfig();

      expect(config.allowOutdated, isEmpty);
    });

    test('correctly parses config options', () async {
      when(() => mockFile.readAsString()).thenAnswer(
        (i) async => '''
name: test
dart_pre_commit:
  allow_outdated:
    - path_1
    - path_2
''',
      );

      final config = await sut.loadConfig();

      expect(config.allowOutdated, const ['path_1', 'path_2']);
    });
  });
}
