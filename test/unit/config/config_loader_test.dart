import 'dart:io';

import 'package:dart_pre_commit/src/config/config_loader.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

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

    group('loadGlobalConfig', () {
      group('without file', () {
        test('uses pubspec.yaml', () async {
          when(() => mockFile.readAsString()).thenReturnAsync('name: test');

          await sut.loadGlobalConfig();

          verifyInOrder([
            () => mockFileResolver.file('pubspec.yaml'),
            () => mockFile.readAsString(),
            () => mockFile.uri,
          ]);
          verifyNoMoreInteractions(mockFile);
          verifyNoMoreInteractions(mockFileResolver);
        });

        test('returns true and sets config to empty map if no config is given',
            () async {
          when(() => mockFile.readAsString()).thenReturnAsync('name: test');

          final result = await sut.loadGlobalConfig();

          expect(result, isTrue);
          expect(sut.debugGlobalConfig, isEmpty);
        });

        test('returns true and sets config to empty map if config is true',
            () async {
          when(() => mockFile.readAsString())
              .thenReturnAsync('dart_pre_commit: true');

          final result = await sut.loadGlobalConfig();

          expect(result, isTrue);
          expect(sut.debugGlobalConfig, isEmpty);
        });

        test('returns false and sets config to empty map if config is false',
            () async {
          when(() => mockFile.readAsString())
              .thenReturnAsync('dart_pre_commit: false');

          final result = await sut.loadGlobalConfig();

          expect(result, isFalse);
          expect(sut.debugGlobalConfig, isEmpty);
        });

        test('returns true and sets config to given map if config is a map',
            () async {
          when(() => mockFile.readAsString()).thenAnswer(
            (i) async => '''
dart_pre_commit:
  key1: value1
  key2: 2
''',
          );

          final result = await sut.loadGlobalConfig();

          expect(result, isTrue);
          expect(sut.debugGlobalConfig, const {
            'key1': 'value1',
            'key2': 2,
          });
        });

        test('throws if config has an invalid value', () async {
          when(() => mockFile.readAsString())
              .thenReturnAsync('dart_pre_commit: 42');

          expect(
            () => sut.loadGlobalConfig(),
            throwsA(
              isException.having(
                (e) => e.toString(),
                'toString()',
                contains('dart_pre_commit'),
              ),
            ),
          );
        });
      });

      group('with custom file', () {
        const testPath = '/test/path.yaml';

        setUp(() {
          when(() => mockFile.path).thenReturn(testPath);
        });

        test('uses custom file', () async {
          when(() => mockFile.readAsString()).thenReturnAsync('name: test');

          await sut.loadGlobalConfig(mockFile);

          verifyInOrder([
            () => mockFile.readAsString(),
            () => mockFile.uri,
            () => mockFile.path,
          ]);
          verifyNoMoreInteractions(mockFile);
          verifyZeroInteractions(mockFileResolver);
        });

        test('returns true and sets config to empty map if no config is given',
            () async {
          when(() => mockFile.readAsString()).thenReturnAsync('');

          final result = await sut.loadGlobalConfig(mockFile);

          expect(result, isTrue);
          expect(sut.debugGlobalConfig, isEmpty);
        });

        test('returns true and sets config to empty map if config is true',
            () async {
          when(() => mockFile.readAsString()).thenReturnAsync('true');

          final result = await sut.loadGlobalConfig(mockFile);

          expect(result, isTrue);
          expect(sut.debugGlobalConfig, isEmpty);
        });

        test('returns false and sets config to empty map if config is false',
            () async {
          when(() => mockFile.readAsString()).thenReturnAsync('false');

          final result = await sut.loadGlobalConfig(mockFile);

          expect(result, isFalse);
          expect(sut.debugGlobalConfig, isEmpty);
        });

        test('returns true and sets config to given map if config is a map',
            () async {
          when(() => mockFile.readAsString()).thenAnswer(
            (i) async => '''
key1: value1
key2: 2
''',
          );

          final result = await sut.loadGlobalConfig(mockFile);

          expect(result, isTrue);
          expect(sut.debugGlobalConfig, const {
            'key1': 'value1',
            'key2': 2,
          });
        });

        test('throws if config has an invalid value', () async {
          when(() => mockFile.readAsString()).thenReturnAsync('42');

          expect(
            () => sut.loadGlobalConfig(mockFile),
            throwsA(
              isException.having(
                (e) => e.toString(),
                'toString()',
                contains(testPath),
              ),
            ),
          );
        });
      });
    });

    group('loadTaskConfig', () {
      testData<Tuple2<String, Matcher>>(
        'returns correct map for given config',
        [
          const Tuple2('', isEmpty),
          const Tuple2('other: false', isEmpty),
          const Tuple2('task: false', isNull),
          const Tuple2('task: true', isEmpty),
          Tuple2(
            '''
task:
  key1: value1
  key2: false
''',
            equals(const {
              'key1': 'value1',
              'key2': false,
            }),
          ),
        ],
        (fixture) async {
          when(() => mockFile.path).thenReturn('');
          when(() => mockFile.readAsString()).thenReturnAsync(fixture.item1);

          await expectLater(sut.loadGlobalConfig(mockFile), completion(isTrue));

          final config = sut.loadTaskConfig('task');
          expect(config, fixture.item2);
        },
        dataToString: (t) => Tuple2(
          t.item1,
          t.item2.describe(StringDescription()),
        ).toString(),
      );

      test('throws exception on invalid task configuration value', () async {
        when(() => mockFile.path).thenReturn('');
        when(() => mockFile.readAsString()).thenReturnAsync('task: 42');

        await expectLater(sut.loadGlobalConfig(mockFile), completion(isTrue));

        expect(() => sut.loadTaskConfig('task'), throwsException);
      });
    });
  });
}
