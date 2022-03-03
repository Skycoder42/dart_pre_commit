import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:dart_pre_commit/src/util/linter_exception.dart';
import 'package:dart_test_tools/dart_test_tools.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../global_mocks.dart';

class FakeAnalysisContextCollection extends Fake
    implements AnalysisContextCollection {}

class FakeResultLocation extends Fake implements ResultLocation {
  @override
  String createLogMessage(String message) => message;
}

abstract class IAnalysisContextCollectionProviderFn {
  AnalysisContextCollection call(Iterable<RepoEntry> repoEntries);
}

class MockAnalysisContextCollectionProviderFn extends Mock
    implements IAnalysisContextCollectionProviderFn {}

class MockTaskLogger extends Mock implements TaskLogger {}

class MockLibExportLinter extends Mock implements LibExportLinter {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeEntry(''));
    registerFallbackValue(Exception());
  });

  group('LibExportTask', () {
    final fakeEntry = FakeEntry('lib/lib.dart');
    final fakeContext = FakeAnalysisContextCollection();

    final mockAccProvider = MockAnalysisContextCollectionProviderFn();
    final mockLogger = MockTaskLogger();
    final mockLinter = MockLibExportLinter();

    late LibExportTask sut;

    setUp(() {
      reset(mockAccProvider);
      reset(mockLogger);
      reset(mockLinter);

      when(() => mockAccProvider.call(any())).thenReturn(fakeContext);

      sut = LibExportTask(
        analysisContextCollectionProvider: mockAccProvider,
        logger: mockLogger,
        linter: mockLinter,
      );
    });

    test('task metadata is correct', () {
      expect(sut.taskName, 'lib-exports');
      expect(sut.callForEmptyEntries, isFalse);
    });

    testData<Tuple2<String, bool>>(
      'matches only dart files',
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

    group('call', () {
      test('calls linter.call with context collection', () async {
        when(() => mockLinter.call()).thenStream(const Stream.empty());

        await sut.call([fakeEntry]);

        verifyInOrder([
          () => mockAccProvider.call([fakeEntry]),
          () => mockLinter.contextCollection = fakeContext,
          () => mockLinter.call(),
        ]);
      });

      testData<Tuple3<FileResult, TaskResult, void Function()>>(
        'correctly maps linter result to task result',
        [
          Tuple3(
            FileResult.accepted(resultLocation: FakeResultLocation()),
            TaskResult.accepted,
            () => mockLogger.debug('OK'),
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
          when(() => mockLinter.call()).thenStream(Stream.value(fixture.item1));

          final result = await sut.call(const []);

          expect(result, fixture.item2);

          verify(fixture.item3);
        },
      );

      testData<Tuple2<Stream<FileResult>, TaskResult>>(
        'Handles multiple results correctly',
        [
          const Tuple2(Stream.empty(), TaskResult.accepted),
          Tuple2(
            Stream.fromIterable(
              [
                FileResult.accepted(resultLocation: FakeResultLocation()),
                FileResult.rejected(
                  reason: '',
                  resultLocation: FakeResultLocation(),
                ),
                FileResult.accepted(resultLocation: FakeResultLocation()),
              ],
            ),
            TaskResult.rejected,
          ),
          Tuple2(
            Stream.fromIterable(
              [
                FileResult.accepted(resultLocation: FakeResultLocation()),
                FileResult.skipped(
                  reason: '',
                  resultLocation: FakeResultLocation(),
                ),
              ],
            ),
            TaskResult.accepted,
          ),
          Tuple2(
            Stream.fromIterable(
              [
                FileResult.accepted(resultLocation: FakeResultLocation()),
                FileResult.failure(
                  error: '',
                  resultLocation: FakeResultLocation(),
                ),
                FileResult.skipped(
                  reason: '',
                  resultLocation: FakeResultLocation(),
                ),
              ],
            ),
            TaskResult.rejected,
          ),
        ],
        (fixture) async {
          when(() => mockLinter.call()).thenStream(fixture.item1);

          final result = await sut.call(const []);

          expect(result, fixture.item2);
        },
      );
    });
  });
}
