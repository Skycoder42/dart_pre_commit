import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import '../../config/config_loader.dart';
import '../../task_base.dart';

abstract interface class _TaskConfig<TState extends TaskBase> {
  String get taskName;

  bool get enabledByDefault;

  TState create(GetIt getIt, YamlMap config);
}

class _SimpleTaskConfig<TTask extends TaskBase> implements _TaskConfig<TTask> {
  @override
  final String taskName;

  @override
  final bool enabledByDefault;

  _SimpleTaskConfig(this.taskName, {required this.enabledByDefault});

  @override
  TTask create(GetIt getIt, YamlMap config) => getIt.get<TTask>();
}

class _ConfigurableTaskConfig<TTask extends TaskBase, TArg>
    implements _TaskConfig<TTask> {
  @override
  final String taskName;
  final TArg Function(Map<String, dynamic> json) _fromJson;

  @override
  final bool enabledByDefault;

  _ConfigurableTaskConfig(
    this.taskName,
    this._fromJson, {
    required this.enabledByDefault,
  });

  @override
  TTask create(GetIt getIt, YamlMap config) {
    final configMap = config.cast<String, dynamic>();
    final parsedConfig = _fromJson(configMap);
    return getIt.get<TTask>(param1: parsedConfig);
  }
}

@internal
@singleton
class TaskLoader {
  final GetIt _getIt;
  final ConfigLoader _configLoader;

  final _tasks = <_TaskConfig>[];

  TaskLoader(this._getIt, this._configLoader);

  void registerTask<TState extends TaskBase>(
    String name, {
    bool enabledByDefault = true,
  }) => _tasks.add(
    _SimpleTaskConfig<TState>(name, enabledByDefault: enabledByDefault),
  );

  void registerConfigurableTask<TState extends TaskBase, TArg>(
    String name,
    TArg Function(Map<String, dynamic> json) fromJson, {
    bool enabledByDefault = true,
  }) => _tasks.add(
    _ConfigurableTaskConfig<TState, TArg>(
      name,
      fromJson,
      enabledByDefault: enabledByDefault,
    ),
  );

  Iterable<TaskBase> loadTasks() sync* {
    for (final task in _tasks) {
      final taskConfig = _configLoader.loadTaskConfig(
        task.taskName,
        enabledByDefault: task.enabledByDefault,
      );

      if (taskConfig != null) {
        yield task.create(_getIt, taskConfig);
      }
    }
  }
}
