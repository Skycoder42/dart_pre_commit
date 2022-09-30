import 'package:riverpod/riverpod.dart';

import '../../config/pubspec_config_loader.dart';
import '../analyze_task.dart';
import '../flutter_compat_task.dart';
import '../format_task.dart';
import '../lib_export_task.dart';
import '../outdated_task.dart';
import '../pull_up_dependencies_task.dart';
import '../test_import_task.dart';
import 'task_loader.dart';

final defaultTasksLoaderProvider = Provider(
  (ref) => DefaultTasksLoader(
    pubspecConfigLoader: ref.watch(pubspecConfigLoaderProvider),
    taskLoader: ref.watch(taskLoaderProvider),
  ),
);

class DefaultTasksLoader {
  final PubspecConfigLoader pubspecConfigLoader;
  final TaskLoader taskLoader;

  const DefaultTasksLoader({
    required this.pubspecConfigLoader,
    required this.taskLoader,
  });

  Future<void> registerDefaultTasks() async {
    final pubspecConfig = await pubspecConfigLoader.loadPubspecConfig();

    taskLoader
      ..registerConfigurableTask(formatTaskProvider)
      ..registerTask(testImportTaskProvider)
      ..registerTask(analyzeTaskProvider);

    if (pubspecConfig.isPublished) {
      taskLoader.registerTask(libExportTaskProvider);
    }

    if (!pubspecConfig.isFlutterProject) {
      taskLoader.registerTask(flutterCompatTaskProvider);
    }

    taskLoader
      ..registerConfigurableTask(outdatedTaskProvider)
      ..registerConfigurableTask(pullUpDependenciesTaskProvider);
  }
}
