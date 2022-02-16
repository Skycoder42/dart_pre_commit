// coverage:ignore-file
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_test_tools/dart_test_tools.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod/riverpod.dart';

import 'config/config.dart';
import 'config/config_loader.dart';
import 'hooks.dart';
import 'task_base.dart';
import 'tasks/analyze_task.dart';
import 'tasks/flutter_compat_task.dart';
import 'tasks/format_task.dart';
import 'tasks/outdated_task.dart';
import 'tasks/pull_up_dependencies_task.dart';
import 'tasks/test_import_task.dart';
import 'util/file_resolver.dart';
import 'util/logger.dart';
import 'util/logging/console_logger.dart';
import 'util/logging/logging_wrapper.dart';
import 'util/logging/simple_logger.dart';
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

    /// Specifies, whether the [FlutterCompatTask] should be enabled.
    @Default(false) bool flutterCompat,

    /// Specifies, whether the [OutdatedTask] in default mode should be enabled.
    ///
    /// The [outdated] value is used to initialize the task with that value.
    OutdatedLevel? outdated,

    /// Specifies, whether the [PullUpDependenciesTask] should be enabled.
    @Default(false) bool pullUpDependencies,

    /// Sets [Hooks.continueOnRejected].
    @Default(false) bool continueOnRejected,

    /// A list of additional tasks to be added to the hook.
    ///
    /// These are added in addition to the four primary tasks. They are always
    /// added last to the hook, so they will also run last. If you need more
    /// control over the order, instanciate the primary tasks by hand, using
    /// [HooksProviderInternal]
    List<TaskBase>? extraTasks,
  }) = _HooksConfig;
}

/// A static class to give scope to [hookProvider].
///
/// If you need access to all the internal providers, use
/// [HooksProviderInternal].
abstract class HooksProvider {
  const HooksProvider._();

  /// Returns a riverpod provider family to create [Hooks].
  ///
  /// This provider uses the dependency injection of riverpod. You have to pass
  /// a [HooksConfig] to the provider to create a corresponding hooks instance.
  ///
  /// Makes use of [HooksProviderInternal] to get all the required parameters
  /// and tasks for the hooks instance.
  static final hookProvider = Provider.family(
    (ref, HooksConfig param) => Hooks(
      logger: ref.watch(HooksProviderInternal.loggerProvider),
      fileResolver: ref.watch(HooksProviderInternal.fileResolverProvider),
      programRunner: ref.watch(HooksProviderInternal.programRunnerProvider),
      continueOnRejected: param.continueOnRejected,
      tasks: [
        if (param.format) ref.watch(HooksProviderInternal.formatProvider),
        if (param.analyze) ref.watch(HooksProviderInternal.analyzeProvider),
        if (param.testImports)
          ref.watch(HooksProviderInternal.testImportProvider),
        if (param.flutterCompat)
          ref.watch(HooksProviderInternal.flutterCompatProvider),
        if (param.outdated != null)
          ref.watch(HooksProviderInternal.outdatedProvider(param.outdated!)),
        if (param.pullUpDependencies)
          ref.watch(HooksProviderInternal.pullUpDependenciesProvider),
        if (param.extraTasks != null) ...param.extraTasks!,
      ],
    ),
  );
}

/// A static class that contains all internally used providers.
abstract class HooksProviderInternal {
  const HooksProviderInternal._();

  /// Defines if ansi color codes are supported.
  ///
  /// Is auto-detected by default, but can be overwritten to explicitly enable
  /// or disable support.
  static final ansiSupportedProvider = StateProvider(
    (ref) => stdout.hasTerminal && stdout.supportsAnsiEscapes,
  );

  /// The path to the configuration file that use used to load a [Config].
  ///
  /// This path is used by the [configLoaderProvider] to resolve the
  /// configuration. By default it is `null`, so the standard `pubspec.yaml`
  /// will be used. However, it can be set to a custom path.
  static final configFilePathProvider = StateProvider<File?>((ref) => null);

  /// A simple provider for [ConsoleLogger] as [Logger]
  static final consoleLoggerProvider = Provider<Logger>(
    (ref) => ConsoleLogger(),
  );

  /// A simple provider for [SimpleLogger] as [Logger]
  static final simpleLoggerProvider = Provider<Logger>(
    (ref) => SimpleLogger(),
  );

  /// Provides either the [consoleLoggerProvider] or [simpleLoggerProvider],
  /// depending on what [ansiSupportedProvider] returns.
  static final loggerProvider = Provider(
    (ref) => ref.watch(ansiSupportedProvider)
        ? ref.watch(consoleLoggerProvider)
        : ref.watch(simpleLoggerProvider),
  );

  /// A simple provider for [TaskLogger]
  ///
  /// This is simply [loggerProvider], but as a [TaskLogger] view.
  static final taskLoggerProvider = Provider<TaskLogger>(
    (ref) => ref.watch(loggerProvider),
  );

  /// A simple provider for [FileResolver].
  static final fileResolverProvider = Provider(
    (ref) => FileResolver(),
  );

  /// A simple provider for [ProgramRunner].
  ///
  /// Uses [taskLoggerProvider].
  static final programRunnerProvider = Provider(
    (ref) => ProgramRunner(
      logger: ref.watch(taskLoggerProvider),
    ),
  );

  /// A simple provider for [FormatTask].
  ///
  /// Uses [programRunnerProvider].
  static final formatProvider = Provider(
    (ref) => FormatTask(
      programRunner: ref.watch(programRunnerProvider),
    ),
  );

  /// A simple provider for [AnalyzeTask].
  ///
  /// Uses [fileResolverProvider], [programRunnerProvider] and
  /// [taskLoggerProvider].
  static final analyzeProvider = Provider(
    (ref) => AnalyzeTask(
      fileResolver: ref.watch(fileResolverProvider),
      programRunner: ref.watch(programRunnerProvider),
      logger: ref.watch(taskLoggerProvider),
    ),
  );

  /// A simple provider for [PullUpDependenciesTask].
  ///
  /// Uses [fileResolverProvider], [programRunnerProvider] and
  /// [taskLoggerProvider].
  static final pullUpDependenciesProvider = Provider(
    (ref) => PullUpDependenciesTask(
      fileResolver: ref.watch(fileResolverProvider),
      programRunner: ref.watch(programRunnerProvider),
      logger: ref.watch(taskLoggerProvider),
    ),
  );

  /// A simple provider for [ConfigLoader]
  ///
  /// Uses [fileResolverProvider].
  static final configLoaderProvider = Provider(
    (ref) => ConfigLoader(
      fileResolver: ref.watch(fileResolverProvider),
    ),
  );

  /// A future provider for a loaded [Config]
  ///
  /// Uses [configLoaderProvider] to call [ConfigLoader.loadConfig] with the
  /// path returned by [configFilePathProvider].
  static final configProvider = FutureProvider<Config>(
    (ref) => ref
        .watch(configLoaderProvider)
        .loadConfig(ref.watch(configFilePathProvider)),
  );

  /// A simple provider for [OutdatedTask].
  ///
  /// Uses [programRunnerProvider] and [taskLoggerProvider].
  static final outdatedProvider = Provider.family(
    (ref, OutdatedLevel level) => OutdatedTask(
      programRunner: ref.watch(programRunnerProvider),
      logger: ref.watch(taskLoggerProvider),
      outdatedLevel: level,
    ),
  );

  /// A simple provider for [AnalysisContextCollection]s, based on a root path.
  static final analysisContextCollectionProvider = Provider.family(
    (ref, String contextRoot) => AnalysisContextCollection(
      includedPaths: [contextRoot],
    ),
  );

  /// @nodoc
  @internal
  static final loggingWrapperProvider = Provider(
    (ref) => LoggingWrapper(ref.watch(taskLoggerProvider)),
  );

  /// A simple provider for [TestImportLinter].
  static final testImportLinterProvider = Provider(
    (ref) => TestImportLinter(ref.watch(loggingWrapperProvider)),
  );

  /// A simple provider for [TestImportTask].
  ///
  /// Uses [analysisContextCollectionProvider], [taskLoggerProvider] and
  /// [testImportLinterProvider].
  static final testImportProvider = Provider(
    (ref) => TestImportTask(
      analysisContextCollectionProvider: (entry) => ref.read(
        analysisContextCollectionProvider(entry.gitRoot.absolute.path),
      ),
      logger: ref.watch(taskLoggerProvider),
      linter: ref.watch(testImportLinterProvider),
    ),
  );

  /// A simple provider for [FlutterCompatTask].
  ///
  /// Uses [programRunnerProvider], [taskLoggerProvider].
  static final flutterCompatProvider = Provider(
    (ref) => FlutterCompatTask(
      programRunner: ref.watch(programRunnerProvider),
      taskLogger: ref.watch(taskLoggerProvider),
    ),
  );
}
