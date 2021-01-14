import 'dart:io';

import 'package:path/path.dart';

import 'analyze_task.dart';
import 'file_resolver.dart';
import 'fix_imports_task.dart';
import 'format_task.dart';
import 'logger.dart';
import 'program_runner.dart';
import 'pull_up_dependencies_task.dart';
import 'repo_entry.dart';
import 'task_base.dart';
import 'task_exception.dart';

/// The result of a LintHooks call.
///
/// See [HookResultX] for extension methods defined on the enum.
enum HookResult {
  /// All is ok, nothing was modified.
  clean,

  /// Files had to be fixed up, but all succeeded and only fully staged files
  /// were affected.
  hasChanges,

  /// Files had to be fixed up, all succeeded but partially staged files had to
  /// be modified.
  hasUnstagedChanges,

  /// At least one hook detected a problem that has to be fixed manually before
  /// the commit can be accepted
  rejected,

  /// An unexpected error occured.
  error,
}

/// Extension methods for [HookResult]
extension HookResultX on HookResult {
  /// Returns a boolean that indicates whether the result should be treated as
  /// success or as failure.
  ///
  /// The following table lists how result codes are interpreted:
  ///
  /// Code                            | Success
  /// --------------------------------|---------
  /// [HookResult.clean]              | true
  /// [HookResult.hasChanges]         | true
  /// [HookResult.hasUnstagedChanges] | false
  /// [HookResult.rejected]           | false
  /// [HookResult.error]              | false
  bool get isSuccess => index <= HookResult.hasChanges.index;

  HookResult _raiseTo(HookResult target) =>
      target.index > index ? target : this;
}

class _RejectedException implements Exception {
  const _RejectedException();
}

/// A callable class the runs the hooks on a repository
///
/// This is the main entrypoint of the library. The class will scan your
/// repository for staged files and run all activated hooks on them, reporting
/// a result. Check the documentation of [FixImportsTask], [FormatTask],
/// [AnalyzeTask] and [PullUpDependenciesTask] for more details on the actual
/// supported hook operations.
class Hooks {
  final FileResolver _fileResolver;
  final ProgramRunner _programRunner;
  final List<TaskBase> _tasks;

  /// The [Logger] instance used to log progress and errors
  final Logger logger;

  /// Specifies, whether processing should continue on rejections.
  ///
  /// Normally, once one of the hook operations detects an unfixable problem,
  /// the whole process is aborted with [HookResult.rejected]. If however
  /// [continueOnRejected] is set to true, instead processing will continue as
  /// usualk. In both cases, [call()] will resolve with [HookResult.rejected].
  final bool continueOnRejected;

  /// Constructs a new [Hooks] instance.
  ///
  /// You can use [fixImports], [format] and [analyze] to specify which hooks to
  /// run. By default, all three of them are enabled.
  ///
  /// If [fixImports] is enabled, all staged files will be scanned for import
  /// order and imports will be sorted, first by category (sdk, package,
  /// relative) and then alphabetically. In addition, package imports of the
  /// current package within lib will be converted to relative imports.
  ///
  /// If [format] is true, then all staged files will be formatted with
  /// `dartfmt`, enabeling all possible fixes.
  ///
  /// If [analyze] is set, as final step, the `dartanalyzer` tool will be run
  /// and collect lints for all staged files. If at least one staged file has
  /// problems, the problems will be printed out and the command will fail.
  /// Lints are not fixed automatically. Instead, you have to fix them yourself
  /// or ignore them.
  ///
  /// The [logger] writes data to [stdout]/[stderr] by default, but a custom
  /// logger can be specified to customize how data is logged. See [Logger]
  /// documentation for more details.
  ///
  /// The [continueOnError] can be used to control error behaviour. See
  /// [this.continueOnError] for details.
  const Hooks({
    required this.logger,
    required FileResolver resolver,
    required ProgramRunner programRunner,
    required List<TaskBase> tasks,
    this.continueOnRejected = false,
  })  : _fileResolver = resolver,
        _programRunner = programRunner,
        _tasks = tasks;

  /// Executes all enabled hooks on the current repository.
  ///
  /// The command will run expecting [Directory.current] to be the git
  /// repository to be processed. It collects all staged files and then runs all
  /// enabled hooks on these files. See [Hooks.create()] for more details on
  /// what hooks are available and how to configure this instance.
  ///
  /// The result is determined based on the collective result of all processed
  /// files and hooks. A [HookResult.clean] result is only possible if all
  /// operations are clean. If at least one staged file had to modified, the
  /// result is [HookResult.hasChanges]. If at least one file was partially
  /// staged, it will be [HookResult.hasUnstagedChanges] instead. The
  /// [HookResult.linter] will be the result if the analyzer finds at least one
  /// file with problems, regardless of error-level or whether files have
  /// already been modified by other hooks. [HookResult.error] trumps all other
  /// results, as at least one error means that the operation has failed.
  Future<HookResult> call() async {
    try {
      var lintState = HookResult.clean;
      final entries = await _collectStagedFiles().toList();

      final fileTasks = _tasks.whereType<FileTask>().toList();
      for (final entry in entries) {
        logger.log('Scanning ${entry.file.path}...');
        var taskResult = TaskResult.accepted;
        for (final task in fileTasks) {
          if (task.canProcess(entry)) {
            taskResult = taskResult.raiseTo(await task(entry));
          }
        }
        lintState = lintState._raiseTo(await _processFileTaskResult(
          entry,
          taskResult,
        ));
      }

      for (final task in _tasks.whereType<RepoTask>()) {
        final filteredEntries = entries.where(task.canProcess).toList();
        if (filteredEntries.isNotEmpty || task.callForEmptyEntries) {
          final taskResult = await task(filteredEntries);
          lintState = lintState._raiseTo(await _processRepoTaskResult(
            filteredEntries,
            taskResult,
          ));
        }
      }

      return lintState;
    } on _RejectedException {
      return HookResult.rejected;
    } on TaskException catch (error) {
      logger.logError(error);
      return HookResult.error;
    }
  }

  Stream<RepoEntry> _collectStagedFiles() async* {
    final gitRoot = await _gitRoot();
    final indexChanges = await _streamGitFiles(gitRoot, [
      'diff',
      '--name-only',
    ]).toList();
    final stagedChanges = _streamGitFiles(gitRoot, [
      'diff',
      '--name-only',
      '--cached',
    ]);

    await for (final path in stagedChanges) {
      final file = _fileResolver.file(path);
      if (!await file.exists()) {
        continue;
      }
      yield RepoEntry(
        file: file,
        partiallyStaged: indexChanges.contains(path),
      );
    }
  }

  Future<String> _gitRoot() async => Directory(
        await _programRunner.stream('git', const [
          'rev-parse',
          '--show-toplevel',
        ]).first,
      ).resolveSymbolicLinks();

  Stream<String> _streamGitFiles(
    String gitRoot,
    List<String> arguments,
  ) async* {
    final resolvedCurrent = await Directory.current.resolveSymbolicLinks();
    yield* _programRunner
        .stream('git', arguments)
        .map((path) => join(gitRoot, path))
        .where((path) => isWithin(resolvedCurrent, path))
        .map((path) => relative(path, from: resolvedCurrent));
  }

  Future<HookResult> _processFileTaskResult(
    RepoEntry entry,
    TaskResult taskResult,
  ) async {
    switch (taskResult) {
      case TaskResult.accepted:
        // TODO print file ok
        return HookResult.clean;
      case TaskResult.modified:
        if (entry.partiallyStaged) {
          logger.log(
            '(!) Fixing up partially staged file ${entry.file.path}',
          );
          return HookResult.hasUnstagedChanges;
        } else {
          logger.log('Fixing up ${entry.file.path}');
          await _programRunner.stream('git', [
            'add',
            entry.file.path,
          ]).drain<void>();
          return HookResult.hasChanges;
        }
      case TaskResult.rejected:
        if (continueOnRejected) {
          return HookResult.rejected;
        } else {
          throw const _RejectedException();
        }
    }
  }

  Future<HookResult> _processRepoTaskResult(
    List<RepoEntry> entries,
    TaskResult taskResult,
  ) async {
    if (entries.isEmpty) {
      switch (taskResult) {
        case TaskResult.accepted:
          return HookResult.clean;
        case TaskResult.modified:
          return HookResult.hasChanges;
        case TaskResult.rejected:
          if (continueOnRejected) {
            return HookResult.rejected;
          } else {
            throw const _RejectedException();
          }
      }
    } else {
      return Stream.fromIterable(entries)
          .asyncMap(
            (entry) => _processFileTaskResult(
              entry,
              taskResult,
            ),
          )
          .fold<HookResult>(
            HookResult.clean,
            (previous, element) => previous._raiseTo(element),
          );
    }
  }
}
