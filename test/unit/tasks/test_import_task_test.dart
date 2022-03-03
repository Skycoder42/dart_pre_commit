import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/test_import_task.dart';
import 'package:dart_pre_commit/src/util/linter_exception.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_test_tools/dart_test_tools.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../global_mocks.dart';

class FakeAnalysisContextCollection extends Fake
    implements AnalysisContextCollection {}

class FakeResultLocation extends Fake implements ResultLocation {
  @override
  String formatMessage(String message) => message;
}

abstract class IAnalysisContextCollectionProviderFn {
  AnalysisContextCollection call(RepoEntry repoEntry);
}

class MockAnalysisContextCollectionProviderFn extends Mock
    implements IAnalysisContextCollectionProviderFn {}

class MockTaskLogger extends Mock implements TaskLogger {}

class MockTestImportLinter extends Mock implements TestImportLinter {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeEntry(''));
    registerFallbackValue(Exception());
  });

  group('TestImportTask', () {
    const fakePath = 'test/mock_test.dart';
    final fakeEntry = FakeEntry(fakePath);
    final fakeContext = FakeAnalysisContextCollection();

    final mockAccProvider = MockAnalysisContextCollectionProviderFn();
    final mockLogger = MockTaskLogger();
    final mockLinter = MockTestImportLinter();

    late TestImportTask sut;

    setUp(() {
      reset(mockAccProvider);
      reset(mockLogger);
      reset(mockLinter);

      when(() => mockAccProvider.call(any())).thenReturn(fakeContext);

      sut = TestImportTask(
        analysisContextCollectionProvider: mockAccProvider,
        logger: mockLogger,
        linter: mockLinter,
      );
    });

    test('task metadata is correct', () {
      expect(sut.taskName, 'test-imports');
    });

    group('canProcess', () {
      testData<Tuple2<String, bool>>(
        'matches only files accepted by the linter',
        const [
          Tuple2('test1.dart', false),
          Tuple2('test/path2.dart', true),
        ],
        (fixture) {
          when(() => mockLinter.shouldAnalyze(any())).thenReturn(fixture.item2);

          expect(
            sut.canProcess(
              RepoEntry(
                file: FakeFile(fixture.item1),
                partiallyStaged: false,
                gitRoot: Directory.systemTemp,
              ),
            ),
            fixture.item2,
          );

          verifyInOrder([
            () => mockLinter.contextCollection = fakeContext,
            () => mockLinter.shouldAnalyze(normalize(absolute(fixture.item1))),
          ]);
        },
      );

      test('does not match files if StateError is thrown', () {
        when(() => mockLinter.shouldAnalyze(any()))
            .thenThrow(StateError('error'));

        expect(sut.canProcess(fakeEntry), isFalse);
      });
    });

    group('call', () {
      test('calls linter.analyzeFile with absolute path', () async {
        when(() => mockLinter.analyzeFile(any())).thenAnswer(
          (i) async => FileResult.accepted(
            resultLocation: FakeResultLocation(),
          ),
        );

        await sut.call(fakeEntry);

        verifyInOrder([
          () => mockLinter.contextCollection = fakeContext,
          () => mockLinter.analyzeFile(normalize(absolute(fakePath)))
        ]);
      });

      testData<Tuple3<FileResult, TaskResult, void Function()?>>(
        'correctly maps linter result to task result',
        [
          Tuple3(
            FileResult.accepted(resultLocation: FakeResultLocation()),
            TaskResult.accepted,
            null,
          ),
          Tuple3(
            FileResult.rejected(
              reason: 'REJECTED',
              resultLocation: FakeResultLocation(),
            ),
            TaskResult.rejected,
            () => mockLogger.error('REJECTED'),
          ),
          Tuple3(
            FileResult.skipped(
              reason: 'SKIPPED',
              resultLocation: FakeResultLocation(),
            ),
            TaskResult.accepted,
            () => mockLogger.info('SKIPPED'),
          ),
          Tuple3(
            FileResult.failure(
              error: 'FAILURE',
              stackTrace: StackTrace.empty,
              resultLocation: FakeResultLocation(),
            ),
            TaskResult.rejected,
            () => mockLogger.except(
              any(
                that: isA<LinterException>().having(
                  (e) => e.message,
                  'message',
                  'FAILURE',
                ),
              ),
              StackTrace.empty,
            ),
          ),
        ],
        (fixture) async {
          when(() => mockLinter.analyzeFile(any()))
              .thenAnswer((i) async => fixture.item1);

          final result = await sut.call(fakeEntry);

          expect(result, fixture.item2);

          if (fixture.item3 != null) {
            verify(fixture.item3!);
          }
        },
      );
    });
  });
}
