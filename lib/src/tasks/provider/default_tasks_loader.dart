import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

import '../../config/pubspec_config_loader.dart';
import '../../util/logger.dart';
import '../../util/program_detector.dart';
import '../analysis_task_base.dart';
import '../analyze_task.dart';
import '../flutter_compat_task.dart';
import '../format_task.dart';
import '../osv_scanner_task.dart';
import '../outdated_task.dart';
import '../pull_up_dependencies_task.dart';
import 'task_loader.dart';

@internal
@injectable
class DefaultTasksLoader {
  final PubspecConfigLoader _pubspecConfigLoader;
  final ProgramDetector _programDetector;
  final TaskLoader _taskLoader;
  final Logger _logger;

  const DefaultTasksLoader({
    required PubspecConfigLoader pubspecConfigLoader,
    required ProgramDetector programDetector,
    required TaskLoader taskLoader,
    required Logger logger,
  }) : _pubspecConfigLoader = pubspecConfigLoader,
       _programDetector = programDetector,
       _taskLoader = taskLoader,
       _logger = logger;

  Future<void> registerDefaultTasks() async {
    final pubspecConfig = await _pubspecConfigLoader.loadPubspecConfig();

    _logger.debug('detected pubspec config: $pubspecConfig');

    _taskLoader
      ..registerConfigurableTask<FormatTask, FormatConfig>(
        FormatTask.name,
        FormatConfig.fromJson,
      )
      ..registerConfigurableTask<AnalyzeTask, AnalysisConfig>(
        AnalyzeTask.name,
        AnalysisConfig.fromJson,
      );

    if (!pubspecConfig.isFlutterProject) {
      _taskLoader.registerTask<FlutterCompatTask>(FlutterCompatTask.name);
    }

    _taskLoader
      ..registerConfigurableTask<OutdatedTask, OutdatedConfig>(
        OutdatedTask.name,
        OutdatedConfig.fromJson,
      )
      ..registerConfigurableTask<
        PullUpDependenciesTask,
        PullUpDependenciesConfig
      >(PullUpDependenciesTask.name, PullUpDependenciesConfig.fromJson);

    final osvScannerFound = await _programDetector.hasProgram(
      OsvScannerTask.osvScannerBinary,
    );
    _logger.debug('osv-scanner found in PATH: $osvScannerFound');
    if (osvScannerFound) {
      _taskLoader.registerConfigurableTask<OsvScannerTask, OsvScannerConfig>(
        OsvScannerTask.name,
        OsvScannerConfig.fromJson,
      );
    }
  }
}
