import 'dart:convert';
import 'dart:io';

import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:dart_pre_commit/src/tasks/library_imports_task.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../test_with_data.dart';

class MockFileResolver extends Mock implements FileResolver {}

class MockTaskLogger extends Mock implements TaskLogger {}

class MockFile extends Mock implements File {}

void main() {
  const packageName = 'mock_package';
  final mockFileResolver = MockFileResolver();
  final mockLogger = MockTaskLogger();
  final mockFile = MockFile();

  late LibraryImportsTask sut;

  setUp(() {
    reset(mockFileResolver);
    reset(mockLogger);
    reset(mockFile);

    when(() => mockFileResolver.resolve(any())).thenAnswer(
      (i) async => canonicalize(i.positionalArguments.first as String),
    );

    sut = LibraryImportsTask(
      packageName: packageName,
      fileResolver: mockFileResolver,
      logger: mockLogger,
    );
  });

  test('task metadata is correct', () {
    expect(sut.taskName, 'library-imports');
  });

  testWithData<Tuple2<String, bool>>(
    'matches only dart files',
    const [
      Tuple2('test.dart', false),
      Tuple2('lib/test.dart', false),
      Tuple2('lib/src/test.dart', true),
      Tuple2('lib/src/another/sub/dir/test.dart', true),
      Tuple2('test/test.dart', true),
      Tuple2('test/unit/api/test.dart', true),
      Tuple2('bin/test.dart', false),
      Tuple2('bin/test/test.dart', false),
      Tuple2('tool/test.dart', false),
      Tuple2('tool/lib/src/test.dart', false),
      Tuple2('test/test2.g.dart', true),
      Tuple2('test/test3.dart.g', false),
      Tuple2('test/test4_dart', false),
      Tuple2('test/test5.dat', false),
    ],
    (fixture) {
      expect(
        sut.filePattern.matchAsPrefix(fixture.item1),
        fixture.item2 ? isNotNull : isNull,
      );
    },
  );

  testWithData<Tuple3<String, TaskResult, String?>>(
    'reports correct result for different inputs',
    const [
      Tuple3(
        '',
        TaskResult.accepted,
        null,
      ),
      Tuple3(
        'import "dart:$packageName.dart"',
        TaskResult.accepted,
        null,
      ),
      Tuple3(
        'import "package:$packageName/src/src.dart"',
        TaskResult.accepted,
        null,
      ),
      Tuple3(
        'import "package:$packageName/src/$packageName.dart"',
        TaskResult.accepted,
        null,
      ),
      Tuple3(
        'import "package:$packageName/$packageName.dart"',
        TaskResult.rejected,
        'absolute',
      ),
      Tuple3(
        'import "package:$packageName/another.dart"',
        TaskResult.rejected,
        'absolute',
      ),
      Tuple3(
        'import "$packageName.dart"',
        TaskResult.accepted,
        null,
      ),
      Tuple3(
        'import "../$packageName.dart"',
        TaskResult.accepted,
        null,
      ),
      Tuple3(
        'import "../$packageName/sub.dart"',
        TaskResult.accepted,
        null,
      ),
      Tuple3(
        'import "$packageName/$packageName.dart"',
        TaskResult.accepted,
        null,
      ),
      Tuple3(
        'import "../../../$packageName.dart"',
        TaskResult.accepted,
        null,
      ),
      Tuple3(
        'import "../../$packageName.dart"',
        TaskResult.rejected,
        'relative',
      ),
      Tuple3(
        'import "../../another.dart"',
        TaskResult.rejected,
        'relative',
      ),
      Tuple3(
        'import "../../libdir/stuff.dart"',
        TaskResult.rejected,
        'relative',
      ),
    ],
    (fixture) async {
      const sutDir = 'lib/src/subdir';
      when(() => mockFile.parent).thenReturn(Directory(sutDir));
      when(() => mockFile.openRead()).thenAnswer(
        (i) => Stream.value(fixture.item1).transform(utf8.encoder),
      );

      final result = await sut(RepoEntry(
        file: mockFile,
        partiallyStaged: false,
      ));

      expect(result, fixture.item2);

      if (fixture.item2 == TaskResult.rejected) {
        verify(
          () => mockLogger.info(
            any(
              that: startsWith(
                'Found ${fixture.item3} import of non-src library: ',
              ),
            ),
          ),
        );
      }
    },
  );

  test('can find multiple imports per file', () async {
    const sutDir = 'lib/src/subdir';
    when(() => mockFile.parent).thenReturn(Directory(sutDir));
    when(() => mockFile.openRead()).thenAnswer(
      (i) => Stream.value('''
import 'dart:io';
import 'package:another/another.dart';
import 'package:$packageName/$packageName.dart';
import '../help.dart';
import '../../$packageName.dart';
import 'package:$packageName/src/$packageName.dart';

void main() {}
''').transform(utf8.encoder),
    );

    final result = await sut(RepoEntry(
      file: mockFile,
      partiallyStaged: false,
    ));

    expect(result, TaskResult.rejected);

    verifyInOrder([
      () => mockLogger.info(
            'Found absolute import of non-src library: '
            'package:$packageName/$packageName.dart',
          ),
      () => mockLogger.info(
            'Found relative import of non-src library: '
            '../../$packageName.dart',
          ),
    ]);
  });
}
