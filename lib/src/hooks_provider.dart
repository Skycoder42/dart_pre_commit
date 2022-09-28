// coverage:ignore-file

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod/riverpod.dart';

import 'hooks.dart';
import 'task_base.dart';
import 'tasks/analyze_task.dart';
import 'tasks/flutter_compat_task.dart';
import 'tasks/format_task.dart';
import 'tasks/lib_export_task.dart';
import 'tasks/outdated_task.dart';
import 'tasks/pull_up_dependencies_task.dart';
import 'tasks/test_import_task.dart';
import 'util/file_resolver.dart';
import 'util/logger.dart';
import 'util/program_runner.dart';

part 'hooks_provider.freezed.dart';

/// The configuration to create dependency-injected [Hooks] via [HooksProvider].
@freezed
class HooksConfig with _$HooksConfig {
  /// Default constructor.
  const factory HooksConfig({
    /// Specifies, whether the [FormatTask] should be enabled.
    @Default(false) bool format,

    /// Specifies, whether the [AnalyzeTask] should be enabled.
    @Default(false) bool analyze,

    /// Specifies, whether the [TestImportTask] should be enabled.
    @Default(false) bool testImports,

    /// Specifies, whether the [LibExportTask] should be enabled.
    @Default(false) bool libExports,

    /// Specifies, whether the [FlutterCompatTask] should be enabled.
    @Default(false) bool flutterCompat,
    OutdatedConfig? outdated,
    PullUpDependenciesConfig? pullUpDependencies,

    /// Sets [Hooks.continueOnRejected].
    @Default(false) bool continueOnRejected,
    List<TaskBase>? extraTasks,
  }) = _HooksConfig;
}

abstract class HooksProvider {
  const HooksProvider._();

  static final hookProvider = Provider.family(
    (ref, HooksConfig param) => Hooks(
      logger: ref.watch(loggerProvider),
      fileResolver: ref.watch(fileResolverProvider),
      programRunner: ref.watch(programRunnerProvider),
      continueOnRejected: param.continueOnRejected,
      tasks: [
        if (param.format) ref.watch(formatTaskProvider),
        if (param.analyze) ref.watch(analyzeTaskProvider),
        if (param.testImports) ref.watch(testImportTaskProvider),
        if (param.libExports) ref.watch(libExportTaskProvider),
        if (param.flutterCompat) ref.watch(flutterCompatTaskProvider),
        if (param.outdated != null)
          ref.watch(outdatedTaskProvider(param.outdated!)),
        if (param.pullUpDependencies != null)
          ref.watch(pullUpDependenciesTaskProvider(param.pullUpDependencies!)),
        if (param.extraTasks != null) ...param.extraTasks!,
      ],
    ),
  );
}
