import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';
import 'package:yaml/yaml.dart';

import '../../config/config_loader.dart';
import '../../task_base.dart';
import 'task_provider.dart';

// coverage:ignore-start
final taskLoaderProvider = Provider(
  (ref) => TaskLoader(
    ref: ref,
    configLoader: ref.watch(configLoaderProvider),
  ),
);
// coverage:ignore-end

abstract class _TaskConfig<TState extends TaskBase> {
  String get taskName;

  TState create(Ref ref, YamlMap config);
}

class _SimpleTaskConfig<TState extends TaskBase> extends _TaskConfig<TState> {
  final TaskProvider<TState> provider;

  _SimpleTaskConfig(this.provider);

  @override
  String get taskName => provider.name;

  @override
  TState create(Ref ref, YamlMap config) => ref.read(provider);
}

class _ConfigurableTaskConfig<TState extends TaskBase, TArg>
    extends _TaskConfig<TState> {
  final ConfigurableTaskProviderFamily<TState, TArg> configurableProvider;

  _ConfigurableTaskConfig(this.configurableProvider);

  @override
  String get taskName => configurableProvider.name;

  @override
  TState create(Ref ref, YamlMap config) {
    final configMap = config.cast<String, dynamic>();
    final parsedConfig = configurableProvider.fromJson(configMap);
    return ref.read(configurableProvider(parsedConfig));
  }
}

class TaskLoader {
  final Ref _ref;
  final ConfigLoader _configLoader;

  final _tasks = <_TaskConfig>[];

  TaskLoader({
    required Ref ref,
    required ConfigLoader configLoader,
  })  : _ref = ref,
        _configLoader = configLoader;

  void registerTask<TState extends TaskBase>(
    TaskProvider<TState> provider,
  ) =>
      _tasks.add(_SimpleTaskConfig<TState>(provider));

  void registerConfigurableTask<TState extends TaskBase, TArg>(
    ConfigurableTaskProviderFamily<TState, TArg> providerFamily,
  ) =>
      _tasks.add(_ConfigurableTaskConfig<TState, TArg>(providerFamily));

  /// @nodoc
  @internal
  Iterable<TaskBase> loadTasks() sync* {
    for (final task in _tasks) {
      final taskConfig = _configLoader.loadTaskConfig(task.taskName);
      if (taskConfig != null) {
        yield task.create(_ref, taskConfig);
      }
    }
  }
}
