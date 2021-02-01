import 'dart:io';

import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/fix_imports_task.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:meta/meta.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../test_with_data.dart';
import 'fix_imports_task_test.mocks.dart';

@GenerateMocks([
  File,
], customMocks: [
  MockSpec<TaskLogger>(returnNullOnMissingStub: true),
])
void main() {
  final mockFile = MockFile();
  final mockLogger = MockTaskLogger();

  late FixImportsTask sut;

  @isTest
  void _runTest(
    String message, {
    required String inData,
    String? outData,
    Function? setUp,
  }) {
    test(message, () async {
      when(mockFile.readAsString()).thenAnswer((_) async => inData);
      if (setUp != null) {
        setUp();
      }

      final res = await sut(RepoEntry(file: mockFile, partiallyStaged: false));
      if (outData != null) {
        expect(res, TaskResult.modified);
        verify(mockFile.writeAsString(outData));
      } else {
        expect(res, TaskResult.accepted);
        verifyNever(mockFile.writeAsString(any));
      }
    });
  }

  setUp(() {
    reset(mockFile);
    reset(mockLogger);

    when(mockFile.path).thenReturn(join('lib', 'tst_mock.dart'));
    when(mockFile.parent).thenReturn(Directory('lib'));
    when(mockFile.writeAsString(any)).thenAnswer(
      (realInvocation) async => mockFile,
    );

    sut = FixImportsTask(
      libDir: Directory('lib'),
      packageName: 'mock',
      logger: mockLogger,
    );
  });

  test('task metadata is correct', () {
    expect(sut.taskName, 'fix-imports');
  });

  testWithData<Tuple2<String, bool>>(
    'matches only dart/pubspec.yaml files',
    const [
      Tuple2('test1.dart', true),
      Tuple2('test/path2.dart', true),
      Tuple2('test3.g.dart', true),
      Tuple2('test4.dart.g', false),
      Tuple2('test5_dart', false),
      Tuple2('test6.dat', false),
    ],
    (fixture) {
      expect(
        sut.filePattern.matchAsPrefix(fixture.item1),
        fixture.item2 ? isNotNull : isNull,
      );
    },
  );

  group('relativize', () {
    _runTest(
      'makes package imports in lib relative',
      inData: 'import "package:mock/src/details.dart";\n',
      outData: 'import "src/details.dart";\n\n',
    );

    _runTest(
      'works for complex imports',
      inData:
          'import "package:mock/src/details.dart" show Details;   // ignore: some lint\n',
      outData:
          'import "src/details.dart" show Details;   // ignore: some lint\n\n',
    );

    _runTest(
      'works for multiline imports',
      inData: '// comment\n'
          'import "package:mock/src/details.dart" // comment\n'
          '  as details; // comment\n',
      outData: '// comment\n'
          'import "src/details.dart" // comment\n'
          '  as details; // comment\n\n',
    );

    _runTest(
      'does not modify imports outside lib',
      inData: 'import "package:mock/src/details.dart";\n',
      setUp: () {
        when(mockFile.path).thenReturn(join('bin', 'tst_mock.dart'));
        when(mockFile.parent).thenReturn(Directory('bin'));
      },
    );

    _runTest(
      'does not modify other package imports',
      inData: 'import "package:mock2/src/details.dart";\n',
    );
  });

  group('sort', () {
    _runTest(
      'sorts imports as expected',
      inData: '''
import 'package:c/c.dart';
import 'dart:io'; // ignore: does_not_work_on_web
import 'dart:async';
import 'package:a/a.dart';
import '../../tree.dart' show Root;
import 'package:b/b.dart' hide B; // B is not needed
import 'package:mock/src/details.dart';
import 'package:d/d.dart';
import 'dart:path';
import '../car.dart';
import '../den.dart'; // stuff
''',
      outData: '''
import 'dart:async';
import 'dart:io'; // ignore: does_not_work_on_web
import 'dart:path';

import 'package:a/a.dart';
import 'package:b/b.dart' hide B; // B is not needed
import 'package:c/c.dart';
import 'package:d/d.dart';

import '../../tree.dart' show Root;
import '../car.dart';
import '../den.dart'; // stuff
import 'src/details.dart';

''',
    );

    _runTest(
      'keeps prefix and suffix lines',
      inData: '''
// prefix
import 'dart:io';
import 'dart:async'
  as suffix;


/// multiline
/// 
/// doc comment

import 'dart:test' // with even more comments
  // even here
  
  hide test;
// and even more comments
void main() {}
''',
      outData: '''
import 'dart:async'
  as suffix;
// prefix
import 'dart:io';
/// multiline
/// 
/// doc comment
import 'dart:test' // with even more comments
  // even here
  hide test;

// and even more comments
void main() {}
''',
    );

    _runTest(
      'fills correct newlines',
      inData: '''
// prefix


import '../code.dart';


import 'dart:io'


  as suffix;


import 'package:a/a.dart';


// some code


''',
      outData: '''
import 'dart:io'
  as suffix;

import 'package:a/a.dart';

// prefix
import '../code.dart';

// some code
''',
    );
  });

  test('current returns task with current project data', () async {
    final sut = await FixImportsTask.current(
      logger: mockLogger,
    );
    expect(sut.libDir.path, 'lib');
    expect(sut.packageName, 'dart_pre_commit');
  });
}
