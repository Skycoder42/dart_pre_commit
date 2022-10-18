import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/lib_export_task.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/linter_exception.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_test_tools/dart_test_tools.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../global_mocks.dart';

class FakeAnalysisContextCollection extends Fake
    implements AnalysisContextCollection {}

class FakeResultLocation extends Fake implements ResultLocation {
  @override
  final String relPath;

  FakeResultLocation(this.relPath);

  @override
  String createLogMessage(String message) => message;

  @override
  String toString() => 'FakeResultLocation($relPath)';
}

class MockTaskLogger extends Mock implements TaskLogger {}

class MockLibExportLinter extends Mock implements LibExportLinter {}

class MockFileResolver extends Mock implements FileResolver {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeEntry(''));
    registerFallbackValue(Exception());
  });

  group('$LibExportTask', () {
    final fakeEntry = FakeEntry('lib/lib.dart');
    final fakeContext = FakeAnalysisContextCollection();

    final mockLogger = MockTaskLogger();
    final mockLinter = MockLibExportLinter();
    final mockFileResolver = MockFileResolver();

    late LibExportTask sut;

    setUp(() async {
      reset(mockLogger);
      reset(mockLinter);
      reset(mockFileResolver);

      when(() => mockFileResolver.resolve(any(), any()))
          .thenAnswer((i) async => i.positionalArguments.first as String);

      sut = LibExportTask(
        contextCollection: fakeContext,
        logger: mockLogger,
        linter: mockLinter,
        fileResolver: mockFileResolver,
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
      const testFile = 'file.dart';
      const otherTestFile = 'other.dart';
      const unstagedTestFile = 'unstaged.dart';

      test('calls linter.call with context collection', () async {
        when(() => mockLinter.call()).thenStream(const Stream.empty());

        await sut.call([fakeEntry]);

        verifyInOrder([
          () => mockLinter.contextCollection = fakeContext,
          () => mockLinter.call(),
        ]);
      });

      testData<Tuple3<FileResult, TaskResult, void Function()>>(
        'correctly maps linter result to task result',
        [
          Tuple3(
            FileResult.accepted(
              resultLocation: FakeResultLocation(testFile),
            ),
            TaskResult.accepted,
            () => mockLogger.debug('OK'),
          ),
          Tuple3(
            FileResult.rejected(
              reason: 'REJECTED',
              resultLocation: FakeResultLocation(testFile),
            ),
            TaskResult.rejected,
            () => mockLogger.error('REJECTED'),
          ),
          Tuple3(
            FileResult.skipped(
              reason: 'SKIPPED',
              resultLocation: FakeResultLocation(testFile),
            ),
            TaskResult.accepted,
            () => mockLogger.info('SKIPPED'),
          ),
          Tuple3(
            FileResult.failure(
              error: 'FAILURE',
              stackTrace: StackTrace.empty,
              resultLocation: FakeResultLocation(testFile),
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

          final result = await sut.call([FakeEntry(testFile)]);

          expect(result, fixture.item2);

          verifyInOrder([
            () => mockLinter.contextCollection = fakeContext,
            () => mockLinter.call(),
            () => mockFileResolver.resolve(testFile),
            fixture.item3,
          ]);
          verifyNoMoreInteractions(mockLinter);
          verifyNoMoreInteractions(mockFileResolver);
          verifyNoMoreInteractions(mockLogger);
        },
      );

      testData<Tuple3<FileResult, TaskResult, void Function()?>>(
        'correctly maps linter result to task result for unstaged files',
        [
          Tuple3(
            FileResult.accepted(
              resultLocation: FakeResultLocation(unstagedTestFile),
            ),
            TaskResult.accepted,
            null,
          ),
          Tuple3(
            FileResult.rejected(
              reason: 'REJECTED',
              resultLocation: FakeResultLocation(unstagedTestFile),
            ),
            TaskResult.accepted,
            null,
          ),
          Tuple3(
            FileResult.skipped(
              reason: 'SKIPPED',
              resultLocation: FakeResultLocation(unstagedTestFile),
            ),
            TaskResult.accepted,
            null,
          ),
          Tuple3(
            FileResult.failure(
              error: 'FAILURE',
              stackTrace: StackTrace.empty,
              resultLocation: FakeResultLocation(unstagedTestFile),
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

          final result = await sut.call([FakeEntry(testFile)]);

          expect(result, fixture.item2);

          verifyInOrder([
            () => mockLinter.contextCollection = fakeContext,
            () => mockLinter.call(),
            () => mockFileResolver.resolve(unstagedTestFile),
            if (fixture.item3 != null) fixture.item3!,
          ]);
          verifyNoMoreInteractions(mockLinter);
          verifyNoMoreInteractions(mockFileResolver);
          verifyNoMoreInteractions(mockLogger);
        },
      );

      testData<Tuple2<Stream<FileResult>, TaskResult>>(
        'Handles multiple results correctly',
        [
          const Tuple2(Stream.empty(), TaskResult.accepted),
          Tuple2(
            Stream.fromIterable(
              [
                FileResult.accepted(
                  resultLocation: FakeResultLocation(testFile),
                ),
                FileResult.rejected(
                  reason: '',
                  resultLocation: FakeResultLocation(testFile),
                ),
                FileResult.accepted(
                  resultLocation: FakeResultLocation(otherTestFile),
                ),
              ],
            ),
            TaskResult.rejected,
          ),
          Tuple2(
            Stream.fromIterable(
              [
                FileResult.accepted(
                  resultLocation: FakeResultLocation(testFile),
                ),
                FileResult.skipped(
                  reason: '',
                  resultLocation: FakeResultLocation(otherTestFile),
                ),
              ],
            ),
            TaskResult.accepted,
          ),
          Tuple2(
            Stream.fromIterable(
              [
                FileResult.accepted(
                  resultLocation: FakeResultLocation(otherTestFile),
                ),
                FileResult.failure(
                  error: '',
                  resultLocation: FakeResultLocation(otherTestFile),
                ),
                FileResult.skipped(
                  reason: '',
                  resultLocation: FakeResultLocation(testFile),
                ),
              ],
            ),
            TaskResult.rejected,
          ),
          Tuple2(
            Stream.fromIterable(
              [
                FileResult.accepted(
                  resultLocation: FakeResultLocation(testFile),
                ),
                FileResult.rejected(
                  reason: 'REJECTED',
                  resultLocation: FakeResultLocation(unstagedTestFile),
                ),
              ],
            ),
            TaskResult.accepted,
          ),
          Tuple2(
            Stream.fromIterable(
              [
                FileResult.accepted(
                  resultLocation: FakeResultLocation(testFile),
                ),
                FileResult.failure(
                  error: 'FAILURE',
                  resultLocation: FakeResultLocation(unstagedTestFile),
                ),
                FileResult.skipped(
                  reason: 'SKIPPED',
                  resultLocation: FakeResultLocation(testFile),
                ),
              ],
            ),
            TaskResult.rejected,
          ),
        ],
        (fixture) async {
          when(() => mockLinter.call()).thenStream(fixture.item1);

          final result = await sut.call([
            FakeEntry(testFile),
            FakeEntry(otherTestFile),
          ]);

          expect(result, fixture.item2);
        },
      );
    });
  });
}
