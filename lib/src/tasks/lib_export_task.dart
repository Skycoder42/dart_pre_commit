import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_test_tools/lint.dart';

import '../../dart_pre_commit.dart';
import '../util/linter_exception.dart';
import '../util/linter_providers.dart';
import 'provider/task_provider.dart';

final libExportTaskProvider = TaskProvider(
  LibExportTask._taskName,
  (ref) => LibExportTask(
    logger: ref.watch(taskLoggerProvider),
    contextCollection: ref.watch(
      analysisContextCollectionProvider([Directory.current.path]),
    ),
    linter: ref.watch(libExportLinterProvider),
    fileResolver: ref.watch(fileResolverProvider),
  ),
);

/// A task that uses a [LibExportLinter] to check for missing exports of src
/// files.
///
/// This task analyses all files in the lib directory. In case a missing export
/// is found, the task result will be [TaskResult.rejected].
///
/// {@category tasks}
class LibExportTask with PatternTaskMixin implements RepoTask {
  static const _taskName = 'lib-exports';

  /// The [TaskLogger] instance used by this task.
  final TaskLogger logger;

  final AnalysisContextCollection contextCollection;

  /// The [LibExportLinter] used by this task.
  final LibExportLinter linter;

  final FileResolver fileResolver;

  /// Default Constructor.
  LibExportTask({
    required this.logger,
    required this.contextCollection,
    required this.linter,
    required this.fileResolver,
  });

  @override
  String get taskName => _taskName;

  @override
  bool get callForEmptyEntries => false;

  @override
  Pattern get filePattern => RegExp(r'^.*\.dart$');

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    linter.contextCollection = contextCollection;

    final entriesList = entries.toList();
    var result = TaskResult.accepted;
    await for (final fileResult in linter()) {
      final hasEntry = await _hasEntryForLocation(
        fileResult.resultLocation,
        entriesList,
      );

      fileResult.when(
        accepted: (resultLocation) {
          if (hasEntry) {
            logger.debug(resultLocation.createLogMessage('OK'));
          }
        },
        rejected: (reason, resultLocation) {
          if (hasEntry) {
            logger.error(resultLocation.createLogMessage(reason));
            result = result.raiseTo(TaskResult.rejected);
          }
        },
        skipped: (reason, resultLocation) {
          if (hasEntry) {
            logger.info(resultLocation.createLogMessage(reason));
          }
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

  Future<bool> _hasEntryForLocation(
    ResultLocation resultLocation,
    Iterable<RepoEntry> entries,
  ) async {
    final actualLocation = await fileResolver.resolve(resultLocation.relPath);
    return entries.any((entry) => entry.file.path == actualLocation);
  }
}
