import 'package:dart_pre_commit/src/config/config_loader.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/provider/task_loader.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

class MockGetIt extends Mock implements GetIt {}

class MockConfigLoader extends Mock implements ConfigLoader {}

class SimpleFakeTask extends Fake implements TaskBase {}

class ConfigurableFakeTask extends Fake implements TaskBase {}

void main() {
  const testTask1Name = 'task-1';
  const testTask2Name = 'task-2';

  group('$TaskLoader', () {
    final mockGetIt = MockGetIt();
    final mockConfigLoader = MockConfigLoader();
    final simpleFakeTask = SimpleFakeTask();
    final configurableFakeTask = ConfigurableFakeTask();

    late TaskLoader sut;

    setUp(() {
      reset(mockGetIt);
      reset(mockConfigLoader);

      when(() => mockGetIt.get<SimpleFakeTask>()).thenReturn(simpleFakeTask);
      when(
        () => mockGetIt.get<ConfigurableFakeTask>(
          param1: any<dynamic>(named: 'param1'),
        ),
      ).thenReturn(configurableFakeTask);

      sut = TaskLoader(mockGetIt, mockConfigLoader);
    });

    group('loadTasks', () {
      test('returns single, non configured task', () {
        when(
          () => mockConfigLoader.loadTaskConfig(any()),
        ).thenReturn(YamlMap());

        sut.registerTask<SimpleFakeTask>(testTask1Name);

        final tasks = sut.loadTasks();

        expect(tasks, [simpleFakeTask]);

        verifyInOrder([
          () => mockConfigLoader.loadTaskConfig(testTask1Name),
          () => mockGetIt.get<SimpleFakeTask>(),
        ]);
        verifyNoMoreInteractions(mockConfigLoader);
        verifyNoMoreInteractions(mockGetIt);
      });

      test('registerTask passes enabledByDefault to config loader', () {
        when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(null);

        sut.registerTask<SimpleFakeTask>(
          testTask1Name,
          enabledByDefault: false,
        );

        final tasks = sut.loadTasks();

        expect(tasks, isEmpty);

        verifyInOrder([
          () => mockConfigLoader.loadTaskConfig(
            testTask1Name,
            enabledByDefault: false,
          ),
        ]);
        verifyNoMoreInteractions(mockConfigLoader);
        verifyZeroInteractions(mockGetIt);
      });

      test('returns empty list if single task is disabled', () {
        when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(null);

        sut.registerTask(testTask1Name);

        final tasks = sut.loadTasks();

        expect(tasks, isEmpty);

        verifyInOrder([() => mockConfigLoader.loadTaskConfig(testTask1Name)]);
        verifyNoMoreInteractions(mockConfigLoader);
        verifyZeroInteractions(mockGetIt);
      });

      test('returns single, configured task', () {
        when(
          () => mockConfigLoader.loadTaskConfig(any()),
        ).thenReturn(YamlMap());

        sut.registerConfigurableTask<ConfigurableFakeTask, Map<String, String>>(
          testTask2Name,
          (c) => c.cast(),
        );

        final tasks = sut.loadTasks();

        expect(tasks, [configurableFakeTask]);

        verifyInOrder([
          () => mockConfigLoader.loadTaskConfig(testTask2Name),
          () => mockGetIt.get<ConfigurableFakeTask>(param1: <String, String>{}),
        ]);
        verifyNoMoreInteractions(mockConfigLoader);
        verifyNoMoreInteractions(mockGetIt);
      });

      test(
        'registerConfigurableTask passes enabledByDefault to config loader',
        () {
          when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(null);

          sut.registerConfigurableTask<
            ConfigurableFakeTask,
            Map<String, String>
          >(testTask2Name, (c) => c.cast(), enabledByDefault: false);

          final tasks = sut.loadTasks();

          expect(tasks, isEmpty);

          verifyInOrder([
            () => mockConfigLoader.loadTaskConfig(
              testTask2Name,
              enabledByDefault: false,
            ),
          ]);
          verifyNoMoreInteractions(mockConfigLoader);
          verifyZeroInteractions(mockGetIt);
        },
      );

      test('returns single, configured task with custom config', () {
        const testMap = {'key1': 'value1', 'key2': 'value2'};
        when(
          () => mockConfigLoader.loadTaskConfig(any()),
        ).thenReturn(YamlMap.wrap(testMap));

        sut.registerConfigurableTask<ConfigurableFakeTask, Map<String, String>>(
          testTask2Name,
          (c) => c.cast(),
        );

        final tasks = sut.loadTasks();

        expect(tasks, [configurableFakeTask]);

        verifyInOrder([
          () => mockConfigLoader.loadTaskConfig(testTask2Name),
          () => mockGetIt.get<ConfigurableFakeTask>(param1: testMap),
        ]);
        verifyNoMoreInteractions(mockConfigLoader);
        verifyNoMoreInteractions(mockGetIt);
      });

      test('returns empty list if configured task is disabled', () {
        when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(null);

        sut.registerConfigurableTask<ConfigurableFakeTask, Map<String, String>>(
          testTask2Name,
          (c) => c.cast(),
        );

        final tasks = sut.loadTasks();

        expect(tasks, isEmpty);

        verifyInOrder([() => mockConfigLoader.loadTaskConfig(testTask2Name)]);
        verifyNoMoreInteractions(mockConfigLoader);
        verifyZeroInteractions(mockGetIt);
      });

      test('returns all enabled tasks', () {
        when(
          () => mockConfigLoader.loadTaskConfig(any()),
        ).thenReturn(YamlMap());

        sut
          ..registerTask<SimpleFakeTask>(testTask1Name)
          ..registerConfigurableTask<ConfigurableFakeTask, Map<String, String>>(
            testTask2Name,
            (c) => c.cast(),
          );

        final tasks = sut.loadTasks();

        expect(tasks, [simpleFakeTask, configurableFakeTask]);

        verifyInOrder([
          () => mockConfigLoader.loadTaskConfig(testTask1Name),
          () => mockGetIt.get<SimpleFakeTask>(),
          () => mockConfigLoader.loadTaskConfig(testTask2Name),
          () => mockGetIt.get<ConfigurableFakeTask>(param1: <String, String>{}),
        ]);
        verifyNoMoreInteractions(mockConfigLoader);
        verifyNoMoreInteractions(mockGetIt);
      });
    });
  });
}
