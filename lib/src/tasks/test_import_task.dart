import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_test_tools/dart_test_tools.dart';
import 'package:path/path.dart';

import '../../dart_pre_commit.dart';

/// A callback the retreives a [AnalysisContextCollection] for a [RepoEntry].
typedef AnalysisContextCollectionProviderFn = AnalysisContextCollection
    Function(RepoEntry entry);

/// An exception that gets thrown to wrap [FileResult.failure] linter results.
class TestImportException implements Exception {
  /// The `error` message of [FileResult.failure].
  final String message;

  /// Default constructor.
  TestImportException(this.message);

  // coverage:ignore-start
  @override
  String toString() => message;
  // coverage:ignore-end
}

/// A task that uses a [TestImportLinter] to check for invalid imports in test
/// files.
///
/// This task analyzes a single file in the `test` directory with the test
/// import linter. In case an invalid import is found, the task will be
/// [TaskResult.rejected].
///
/// {@category tasks}
class TestImportTask implements FileTask {
  /// The [AnalysisContextCollectionProviderFn] used by this task.
  final AnalysisContextCollectionProviderFn analysisContextCollectionProvider;

  /// The [TaskLogger] instance used by this task.
  final TaskLogger logger;

  /// The [TestImportLinter] used by this task.
  final TestImportLinter linter;

  @override
  String get taskName => 'test-imports';

  /// Default Constructor.
  const TestImportTask({
    required this.analysisContextCollectionProvider,
    required this.logger,
    required this.linter,
  });

  @override
  bool canProcess(RepoEntry entry) {
    try {
      linter.contextCollection = analysisContextCollectionProvider(entry);
      return linter.shouldAnalyze(_normalizedAbsolutePath(entry));
      // ignore: avoid_catching_errors
    } on StateError {
      return false;
    }
  }

  @override
  Future<TaskResult> call(RepoEntry entry) async {
    linter.contextCollection = analysisContextCollectionProvider(entry);
    final result = await linter.analyzeFile(_normalizedAbsolutePath(entry));
    return result.when(
      accepted: (_) => TaskResult.accepted,
      rejected: (reason, resultLocation) {
        logger.error(resultLocation.formatMessage(reason));
        return TaskResult.rejected;
      },
      skipped: (reason, resultLocation) {
        logger.info(resultLocation.formatMessage(reason));
        return TaskResult.accepted;
      },
      failure: (error, stackTrace, resultLocation) {
        logger.except(
          TestImportException(resultLocation.formatMessage(error)),
          stackTrace,
        );
        return TaskResult.rejected;
      },
    );
  }

  String _normalizedAbsolutePath(RepoEntry entry) =>
      normalize(entry.file.absolute.resolveSymbolicLinksSync());
}
