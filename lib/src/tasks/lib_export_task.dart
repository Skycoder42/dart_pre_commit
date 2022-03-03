import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_test_tools/lint.dart';

import '../../dart_pre_commit.dart';
import '../util/linter_exception.dart';

/// A callback the retrieves a [AnalysisContextCollection] for a [RepoEntry].
typedef AnalysisContextCollectionRepoProviderFn = AnalysisContextCollection
    Function(Iterable<RepoEntry> entries);

/// A task that uses a [LibExportLinter] to check for missing exports of src
/// files.
///
/// This task analyses all files in the lib directory. In case a missing export
/// is found, the task result will be [TaskResult.rejected].
///
/// {@category tasks}
class LibExportTask with PatternTaskMixin implements RepoTask {
  /// The [AnalysisContextCollectionRepoProviderFn] used by this task.
  final AnalysisContextCollectionRepoProviderFn
      analysisContextCollectionProvider;

  /// The [TaskLogger] instance used by this task.
  final TaskLogger logger;

  /// The [LibExportLinter] used by this task.
  final LibExportLinter linter;

  /// Default Constructor.
  LibExportTask({
    required this.analysisContextCollectionProvider,
    required this.logger,
    required this.linter,
  });

  @override
  String get taskName => 'lib-exports';

  @override
  bool get callForEmptyEntries => false;

  @override
  Pattern get filePattern => RegExp(r'^.*\.dart$');

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    linter.contextCollection = analysisContextCollectionProvider(entries);
    var result = TaskResult.accepted;
    await for (final fileResult in linter()) {
      fileResult.when(
        accepted: (resultLocation) {
          logger.debug(resultLocation.createLogMessage('OK'));
        },
        rejected: (reason, resultLocation) {
          logger.error(resultLocation.createLogMessage(reason));
          result = result.raiseTo(TaskResult.rejected);
        },
        skipped: (reason, resultLocation) {
          logger.info(resultLocation.createLogMessage(reason));
        },
        failure: (error, stackTrace, resultLocation) {
          logger.except(
            LinterException(resultLocation.createLogMessage(error)),
            stackTrace,
          );
          result = result.raiseTo(TaskResult.rejected);
        },
      );
    }

    return result;
  }
}
