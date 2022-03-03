import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_test_tools/dart_test_tools.dart';
import 'package:path/path.dart';

import '../../dart_pre_commit.dart';
import '../util/linter_exception.dart';

/// A callback the retrieves a [AnalysisContextCollection] for a [RepoEntry].
typedef AnalysisContextCollectionEntryProviderFn = AnalysisContextCollection
    Function(RepoEntry entry);

/// A task that uses a [TestImportLinter] to check for invalid imports in test
/// files.
///
/// This task analyzes a single file in the `test` directory with the test
/// import linter. In case an invalid import is found, the task will be
/// [TaskResult.rejected].
///
/// {@category tasks}
class TestImportTask implements FileTask {
  /// The [AnalysisContextCollectionEntryProviderFn] used by this task.
  final AnalysisContextCollectionEntryProviderFn
      analysisContextCollectionProvider;

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
          LinterException(resultLocation.formatMessage(error)),
          stackTrace,
        );
        return TaskResult.rejected;
      },
    );
  }

  String _normalizedAbsolutePath(RepoEntry entry) =>
      normalize(entry.file.absolute.resolveSymbolicLinksSync());
}
