import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_test_tools/dart_test_tools.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/linter_exception.dart';
import '../util/linter_providers.dart';
import '../util/logger.dart';
import 'provider/task_provider.dart';

// coverage:ignore-start
final testImportTaskProvider = TaskProvider(
  TestImportTask._taskName,
  (ref) => TestImportTask(
    analysisContextCollectionProvider: (entry) => ref.read(
      analysisContextCollectionProvider([entry.gitRoot.absolute.path]),
    ),
    logger: ref.watch(taskLoggerProvider),
    linter: ref.watch(testImportLinterProvider),
  ),
);
// coverage:ignore-end

@internal
typedef AnalysisContextCollectionEntryProviderFn = AnalysisContextCollection
    Function(RepoEntry entry);

@internal
class TestImportTask implements FileTask {
  static const _taskName = 'test-imports';

  final AnalysisContextCollectionEntryProviderFn
      analysisContextCollectionProvider;

  final TaskLogger logger;

  final TestImportLinter linter;

  @override
  String get taskName => _taskName;

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
