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
/// A riverpod provider for the test imports task.
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

/// @nodoc
@internal
typedef AnalysisContextCollectionEntryProviderFn = AnalysisContextCollection
    Function(RepoEntry entry);

/// @nodoc
@internal
class TestImportTask implements FileTask {
  static const _taskName = 'test-imports';

  final AnalysisContextCollectionEntryProviderFn
      _analysisContextCollectionProvider;

  final TaskLogger _logger;

  final TestImportLinter _linter;

  @override
  String get taskName => _taskName;

  /// @nodoc
  const TestImportTask({
    required AnalysisContextCollectionEntryProviderFn
        analysisContextCollectionProvider,
    required TaskLogger logger,
    required TestImportLinter linter,
  })  : _analysisContextCollectionProvider = analysisContextCollectionProvider,
        _logger = logger,
        _linter = linter;

  @override
  bool canProcess(RepoEntry entry) {
    try {
      _linter.contextCollection = _analysisContextCollectionProvider(entry);
      return _linter.shouldAnalyze(_normalizedAbsolutePath(entry));
      // ignore: avoid_catching_errors
    } on StateError {
      return false;
    }
  }

  @override
  Future<TaskResult> call(RepoEntry entry) async {
    _linter.contextCollection = _analysisContextCollectionProvider(entry);
    final result = await _linter.analyzeFile(_normalizedAbsolutePath(entry));
    return result.when(
      accepted: (_) => TaskResult.accepted,
      rejected: (reason, resultLocation) {
        _logger.error(resultLocation.formatMessage(reason));
        return TaskResult.rejected;
      },
      skipped: (reason, resultLocation) {
        _logger.info(resultLocation.formatMessage(reason));
        return TaskResult.accepted;
      },
      failure: (error, stackTrace, resultLocation) {
        _logger.except(
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
