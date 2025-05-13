import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';
import 'package:yaml/yaml.dart';

import '../../config/config_loader.dart';
import '../../hooks.dart';
import '../../task_base.dart';
import 'task_provider.dart';

// coverage:ignore-start
/// A riverpod provider for the [TaskLoader]
final taskLoaderProvider = Provider(
  (ref) => TaskLoader(ref: ref, configLoader: ref.watch(configLoaderProvider)),
);
// coverage:ignore-end

abstract interface class _TaskConfig<TState extends TaskBase> {
  String get taskName;

  bool get enabledByDefault;

  TState create(Ref ref, YamlMap config);
}

class _SimpleTaskConfig<TState extends TaskBase>
    implements _TaskConfig<TState> {
  final TaskProvider<TState> provider;

  @override
  final bool enabledByDefault;

  _SimpleTaskConfig(this.provider, {required this.enabledByDefault});

  @override
  String get taskName => provider.name;

  @override
  TState create(Ref ref, YamlMap config) => ref.read(provider.provider);
}

class _ConfigurableTaskConfig<TState extends TaskBase, TArg>
    implements _TaskConfig<TState> {
  final ConfigurableTaskProviderFamily<TState, TArg> configurableProvider;

  @override
  final bool enabledByDefault;

  _ConfigurableTaskConfig(
    this.configurableProvider, {
    required this.enabledByDefault,
  });

  @override
  String get taskName => configurableProvider.name;

  @override
  TState create(Ref ref, YamlMap config) {
    final configMap = config.cast<String, dynamic>();
    final parsedConfig = configurableProvider.fromJson(configMap);
    return ref.read(configurableProvider(parsedConfig));
  }
}

/// A helper class to register [TaskProvider]s in the application to be used by
/// the [Hooks] instance.
class TaskLoader {
  final Ref _ref;
  final ConfigLoader _configLoader;

  final _tasks = <_TaskConfig>[];

  /// Default constructor
  TaskLoader({required Ref ref, required ConfigLoader configLoader})
    : _ref = ref,
      _configLoader = configLoader;

  /// Registers a simple, unconfigurable task provider.
  ///
  /// You can use the [TaskProvider] to create such providers.
  void registerTask<TState extends TaskBase>(
    TaskProvider<TState> provider, {
    bool enabledByDefault = true,
  }) => _tasks.add(
    _SimpleTaskConfig<TState>(provider, enabledByDefault: enabledByDefault),
  );

  /// Registers a configurable task provider.
  ///
  /// You can use the [TaskProvider.configurable] to create such providers.
  void registerConfigurableTask<TState extends TaskBase, TArg>(
    ConfigurableTaskProviderFamily<TState, TArg> providerFamily, {
    bool enabledByDefault = true,
  }) => _tasks.add(
    _ConfigurableTaskConfig<TState, TArg>(
      providerFamily,
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
        yield task.create(_ref, taskConfig);
      }
    }
  }
}
