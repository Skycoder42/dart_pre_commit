import 'package:riverpod/riverpod.dart';

import '../../config/pubspec_config_loader.dart';
import '../../util/logger.dart';
import '../../util/program_detector.dart';
import '../analyze_task.dart';
import '../custom_lint_task.dart';
import '../flutter_compat_task.dart';
import '../format_task.dart';
import '../osv_scanner_task.dart';
import '../outdated_task.dart';
import '../pull_up_dependencies_task.dart';
import 'task_loader.dart';

// coverage:ignore-start
/// A riverpod provider for the [DefaultTasksLoader].
final defaultTasksLoaderProvider = Provider(
  (ref) => DefaultTasksLoader(
    pubspecConfigLoader: ref.watch(pubspecConfigLoaderProvider),
    programDetector: ref.watch(programDetectorProvider),
    taskLoader: ref.watch(taskLoaderProvider),
    logger: ref.watch(loggerProvider),
  ),
);
// coverage:ignore-end

/// A helper class to automatically register all tasks that are provided with
/// this package in the [TaskLoader].
class DefaultTasksLoader {
  final PubspecConfigLoader _pubspecConfigLoader;
  final ProgramDetector _programDetector;
  final TaskLoader _taskLoader;
  final Logger _logger;

  /// Default constructor.
  const DefaultTasksLoader({
    required PubspecConfigLoader pubspecConfigLoader,
    required ProgramDetector programDetector,
    required TaskLoader taskLoader,
    required Logger logger,
  })  : _pubspecConfigLoader = pubspecConfigLoader,
        _programDetector = programDetector,
        _taskLoader = taskLoader,
        _logger = logger;

  /// Performs the registration of the default tasks.
  ///
  /// This will register the following task providers with the [TaskLoader]:
  /// - [formatTaskProvider]
  /// - [customLintTaskProvider]
  /// - [analyzeTaskProvider]
  /// - [outdatedTaskProvider]
  /// - [pullUpDependenciesTaskProvider]
  ///
  /// If the project is not a flutter project, the [flutterCompatTaskProvider]
  /// is added as well.
  Future<void> registerDefaultTasks() async {
    final pubspecConfig = await _pubspecConfigLoader.loadPubspecConfig();

    _logger.debug('detected pubspec config: $pubspecConfig');

    _taskLoader
      ..registerConfigurableTask(formatTaskProvider)
      ..registerConfigurableTask(analyzeTaskProvider)
      ..registerTask(customLintTaskProvider);

    if (!pubspecConfig.isFlutterProject) {
      _taskLoader.registerTask(flutterCompatTaskProvider);
    }

    _taskLoader
      ..registerConfigurableTask(outdatedTaskProvider)
      ..registerConfigurableTask(pullUpDependenciesTaskProvider);

    final osvScannerFound = await _programDetector.hasProgram(
      OsvScannerTask.osvScannerBinary,
    );
    _logger.debug('osv-scanner found in PATH: $osvScannerFound');
    if (osvScannerFound) {
      _taskLoader.registerTask(osvScannerTaskProvider);
    }
  }
}
