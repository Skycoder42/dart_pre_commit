/// @docImport('../../../dart_pre_commit.dart')
library;

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import '../../config/config_loader.dart';
import '../../dart_pre_commit.dart' show DartPreCommit;
import '../../task_base.dart';

abstract interface class _TaskConfig<TTask extends TaskBase> {
  String get taskName;

  bool get enabledByDefault;

  TTask create(GetIt getIt, YamlMap config);
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

class _CustomTaskConfig<TTask extends TaskBase> implements _TaskConfig<TTask> {
  @override
  final String taskName;

  @override
  final bool enabledByDefault;

  final TTask Function() _factory;

  _CustomTaskConfig(
    this.taskName,
    this._factory, {
    required this.enabledByDefault,
  });

  @override
  TTask create(GetIt getIt, YamlMap config) => _factory();
}

/// A helper class to register [TaskBase]s in the application to be used by
/// the [DartPreCommit] instance.
@singleton
class TaskLoader {
  final GetIt _getIt;
  final ConfigLoader _configLoader;

  final _tasks = <_TaskConfig>[];

  /// Default constructor
  TaskLoader(this._getIt, this._configLoader);

  /// Registers a custom task using the given [factory] function to create new
  /// instances.
  void registerCustomTask<TTask extends TaskBase>(
    String name,
    TTask Function() factory, {
    bool enabledByDefault = true,
  }) => _tasks.add(
    _CustomTaskConfig<TTask>(name, factory, enabledByDefault: enabledByDefault),
  );

  /// @nodoc
  @internal
  void registerTask<TTask extends TaskBase>(
    String name, {
    bool enabledByDefault = true,
  }) => _tasks.add(
    _SimpleTaskConfig<TTask>(name, enabledByDefault: enabledByDefault),
  );

  /// @nodoc
  @internal
  void registerConfigurableTask<TTask extends TaskBase, TArg>(
    String name,
    TArg Function(Map<String, dynamic> json) fromJson, {
    bool enabledByDefault = true,
  }) => _tasks.add(
    _ConfigurableTaskConfig<TTask, TArg>(
      name,
      fromJson,
      enabledByDefault: enabledByDefault,
    ),
  );

  /// @nodoc
  @internal
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
