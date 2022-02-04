import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_test_tools/dart_test_tools.dart';
import 'package:path/path.dart';

import '../../dart_pre_commit.dart';

typedef AnalysisContextCollectionProviderFn = AnalysisContextCollection
    Function(RepoEntry entry);

class TestImportException implements Exception {
  final String message;

  TestImportException(this.message);

  @override
  String toString() => message;
}

class TestImportTask implements FileTask {
  /// The [AnalysisContextCollectionProviderFn] used by this task.
  final AnalysisContextCollectionProviderFn analysisContextCollectionProvider;

  /// The [TaskLogger] instance used by this task.
  final TaskLogger logger;

  /// The [TestImportLinter] used by this task.
  final TestImportLinter linter;

  @override
  String get taskName => 'test-imports';

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
