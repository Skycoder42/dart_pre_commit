// ignore_for_file: unnecessary_lambdas

import 'dart:io';

import 'package:dart_pre_commit/src/config/pubspec_config_loader.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_test_tools/dart_test_tools.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockFileResolver extends Mock implements FileResolver {}

class MockFile extends Mock implements File {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('$PubspecConfigLoader', () {
    final mockFileResolver = MockFileResolver();
    final mockFile = MockFile();
    final mockLogger = MockLogger();

    late PubspecConfigLoader sut;

    setUp(() {
      reset(mockFileResolver);
      reset(mockFile);
      reset(mockLogger);

      when(() => mockFileResolver.file(any())).thenReturn(mockFile);

      sut = PubspecConfigLoader(
        fileResolver: mockFileResolver,
        logger: mockLogger,
      );
    });

    group('loadPubspecConfig', () {
      test('returns default data and logs warning if pubspec was not found',
          () async {
        when(() => mockFile.existsSync()).thenReturn(false);

        final result = await sut.loadPubspecConfig();

        verifyInOrder([
          () => mockFileResolver.file('pubspec.yaml'),
          () => mockFile.existsSync(),
          () => mockLogger.warn(any()),
        ]);

        expect(result.isFlutterProject, isFalse);
        expect(result.isPublished, isTrue);
      });

      test('returns default data if entries are not found in pubspec',
          () async {
        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.uri).thenReturn(Uri());
        when(() => mockFile.readAsString()).thenReturnAsync('name: app');

        final result = await sut.loadPubspecConfig();

        verifyInOrder([
          () => mockFileResolver.file('pubspec.yaml'),
          () => mockFile.existsSync(),
          () => mockFile.readAsString(),
          () => mockFile.uri,
        ]);

        expect(result.isFlutterProject, isFalse);
        expect(result.isPublished, isTrue);
      });

      test('returns custom data if entries are found in pubspec', () async {
        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.uri).thenReturn(Uri());
        when(() => mockFile.readAsString()).thenReturnAsync('''
name: app
publish_to: none

dependencies:
  flutter:
    sdk: flutter
''');

        final result = await sut.loadPubspecConfig();

        verifyInOrder([
          () => mockFileResolver.file('pubspec.yaml'),
          () => mockFile.existsSync(),
          () => mockFile.readAsString(),
          () => mockFile.uri,
        ]);

        expect(result.isFlutterProject, isTrue);
        expect(result.isPublished, isFalse);
      });
    });
  });
}
