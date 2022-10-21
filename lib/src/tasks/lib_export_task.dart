import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_test_tools/lint.dart';
import 'package:meta/meta.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/file_resolver.dart';
import '../util/linter_exception.dart';
import '../util/linter_providers.dart';
import '../util/logger.dart';
import 'provider/task_provider.dart';

// coverage:ignore-start
/// A riverpod provider for the library exports task.
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
// coverage:ignore-end

/// @nodoc
@internal
class LibExportTask with PatternTaskMixin implements RepoTask {
  static const _taskName = 'lib-exports';

  final TaskLogger _logger;

  final AnalysisContextCollection _contextCollection;

  final LibExportLinter _linter;

  final FileResolver _fileResolver;

  /// @nodoc
  LibExportTask({
    required TaskLogger logger,
    required AnalysisContextCollection contextCollection,
    required LibExportLinter linter,
    required FileResolver fileResolver,
  })  : _logger = logger,
        _contextCollection = contextCollection,
        _linter = linter,
        _fileResolver = fileResolver;

  @override
  String get taskName => _taskName;

  @override
  bool get callForEmptyEntries => false;

  @override
  Pattern get filePattern => RegExp(r'^.*\.dart$');

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    _linter.contextCollection = _contextCollection;

    final entriesList = entries.toList();
    var result = TaskResult.accepted;
    await for (final fileResult in _linter()) {
      final hasEntry = await _hasEntryForLocation(
        fileResult.resultLocation,
        entriesList,
      );

      fileResult.when(
        accepted: (resultLocation) {
          if (hasEntry) {
            _logger.debug(resultLocation.createLogMessage('OK'));
          }
        },
        rejected: (reason, resultLocation) {
          if (hasEntry) {
            _logger.error(resultLocation.createLogMessage(reason));
            result = result.raiseTo(TaskResult.rejected);
          }
        },
        skipped: (reason, resultLocation) {
          if (hasEntry) {
            _logger.info(resultLocation.createLogMessage(reason));
          }
        },
        failure: (error, stackTrace, resultLocation) {
          _logger.except(
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
    final actualLocation = await _fileResolver.resolve(resultLocation.relPath);
    return entries.any((entry) => entry.file.path == actualLocation);
  }
}
