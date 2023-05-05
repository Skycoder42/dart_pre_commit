import 'dart:async';

import 'package:meta/meta.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';
import 'provider/task_provider.dart';

// coverage:ignore-start
/// A riverpod provider for the custom-lint task.
final customLintTaskProvider = TaskProvider(
  CustomLintTask._taskName,
  (ref) => CustomLintTask(
    programRunner: ref.watch(programRunnerProvider),
    logger: ref.watch(taskLoggerProvider),
  ),
);
// coverage:ignore-end

/// @nodoc
@internal
class CustomLintTask implements RepoTask {
  static const _taskName = 'custom-lint';

  final ProgramRunner _programRunner;

  final TaskLogger _logger;

  /// @nodoc
  const CustomLintTask({
    required ProgramRunner programRunner,
    required TaskLogger logger,
  })  : _programRunner = programRunner,
        _logger = logger;

  @override
  String get taskName => _taskName;

  @override
  bool get callForEmptyEntries => true;

  @override
  bool canProcess(RepoEntry entry) => true;

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    final resultCompleter = Completer<TaskResult>();

    _programRunner
        .stream('dart', const ['run', 'custom_lint'], runInShell: true)
        .listen(
      _logger.info,
      cancelOnError: true,
      onDone: () {
        if (resultCompleter.isCompleted) {
          return;
        }

        resultCompleter.complete(TaskResult.accepted);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (resultCompleter.isCompleted) {
          return;
        }

        if (error is ProgramExitException && error.exitCode == 1) {
          resultCompleter.complete(TaskResult.rejected);
        } else {
          resultCompleter.completeError(error, stackTrace);
        }
      },
    );

    return resultCompleter.future;
  }
}
