import 'package:dart_pre_commit/src/config/config_loader.dart';
import 'package:dart_pre_commit/src/task_base.dart';
import 'package:dart_pre_commit/src/tasks/provider/task_loader.dart';
import 'package:dart_pre_commit/src/tasks/provider/task_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

class MockConfigLoader extends Mock implements ConfigLoader {}

class MockRef extends Mock implements Ref {}

class FakeTaskBase extends Fake implements TaskBase {
  Map<String, String>? config;
}

final task1Provider = TaskProvider('task-1', (ref) => FakeTaskBase());

final task2Provider = TaskProvider.configurable(
  'task-2',
  (json) => json.cast<String, String>(),
  (ref, arg) => FakeTaskBase()..config = arg,
);

void main() {
  setUpAll(() {
    registerFallbackValue(task1Provider);
  });

  group('$TaskLoader', () {
    final mockConfigLoader = MockConfigLoader();
    final mockRef = MockRef();
    final fakeTask = FakeTaskBase();

    late TaskLoader sut;

    setUp(() {
      reset(mockConfigLoader);
      reset(mockRef);

      when(() => mockRef.read<FakeTaskBase>(any())).thenReturn(fakeTask);

      sut = TaskLoader(ref: mockRef, configLoader: mockConfigLoader);
    });

    group('loadTasks', () {
      test('returns single, non configured task', () {
        when(
          () => mockConfigLoader.loadTaskConfig(any()),
        ).thenReturn(YamlMap());

        sut.registerTask(task1Provider);

        final tasks = sut.loadTasks();

        expect(tasks, [fakeTask]);

        verifyInOrder([
          () => mockConfigLoader.loadTaskConfig(task1Provider.name),
          () => mockRef.read(task1Provider),
        ]);
        verifyNoMoreInteractions(mockConfigLoader);
        verifyNoMoreInteractions(mockRef);
      });

      test('registerTask passes enabledByDefault to config loader', () {
        when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(null);

        sut.registerTask(task1Provider, enabledByDefault: false);

        final tasks = sut.loadTasks();

        expect(tasks, isEmpty);

        verifyInOrder([
          () => mockConfigLoader.loadTaskConfig(
            task1Provider.name,
            enabledByDefault: false,
          ),
        ]);
        verifyNoMoreInteractions(mockConfigLoader);
        verifyZeroInteractions(mockRef);
      });

      test('returns empty list if single task is disabled', () {
        when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(null);

        sut.registerTask(task1Provider);

        final tasks = sut.loadTasks();

        expect(tasks, isEmpty);

        verifyInOrder([
          () => mockConfigLoader.loadTaskConfig(task1Provider.name),
        ]);
        verifyNoMoreInteractions(mockConfigLoader);
        verifyZeroInteractions(mockRef);
      });

      test('returns single, configured task', () {
        when(
          () => mockConfigLoader.loadTaskConfig(any()),
        ).thenReturn(YamlMap());

        sut.registerConfigurableTask(task2Provider);

        final tasks = sut.loadTasks();

        expect(tasks, [fakeTask]);

        final captured =
            verifyInOrder([
                  () => mockConfigLoader.loadTaskConfig(task2Provider.name),
                  () => mockRef.read<FakeTaskBase>(captureAny()),
                ]).captured[1].single
                as Provider<FakeTaskBase>;
        verifyNoMoreInteractions(mockConfigLoader);
        verifyNoMoreInteractions(mockRef);

        expect(captured.name, task2Provider.name);
        expect(captured.argument, isEmpty);
      });

      test(
        'registerConfigurableTask passes enabledByDefault to config loader',
        () {
          when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(null);

          sut.registerConfigurableTask(task2Provider, enabledByDefault: false);

          final tasks = sut.loadTasks();

          expect(tasks, isEmpty);

          verifyInOrder([
            () => mockConfigLoader.loadTaskConfig(
              task2Provider.name,
              enabledByDefault: false,
            ),
          ]);
          verifyNoMoreInteractions(mockConfigLoader);
          verifyZeroInteractions(mockRef);
        },
      );

      test('returns single, configured task with custom config', () {
        const testMap = {'key1': 'value1', 'key2': 'value2'};
        when(
          () => mockConfigLoader.loadTaskConfig(any()),
        ).thenReturn(YamlMap.wrap(testMap));

        sut.registerConfigurableTask(task2Provider);

        final tasks = sut.loadTasks();

        expect(tasks, [fakeTask]);

        final captured =
            verifyInOrder([
                  () => mockConfigLoader.loadTaskConfig(task2Provider.name),
                  () => mockRef.read<FakeTaskBase>(captureAny()),
                ]).captured[1].single
                as Provider<FakeTaskBase>;
        verifyNoMoreInteractions(mockConfigLoader);
        verifyNoMoreInteractions(mockRef);

        expect(captured.name, task2Provider.name);
        expect(captured.argument, testMap);
      });

      test('returns empty list if configured task is disabled', () {
        when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(null);

        sut.registerConfigurableTask(task2Provider);

        final tasks = sut.loadTasks();

        expect(tasks, isEmpty);

        verifyInOrder([
          () => mockConfigLoader.loadTaskConfig(task2Provider.name),
        ]);
        verifyNoMoreInteractions(mockConfigLoader);
        verifyZeroInteractions(mockRef);
      });

      test('returns all enabled tasks', () {
        when(
          () => mockConfigLoader.loadTaskConfig(any()),
        ).thenReturn(YamlMap());

        sut
          ..registerTask(task1Provider)
          ..registerConfigurableTask(task2Provider);

        final tasks = sut.loadTasks();

        expect(tasks, [fakeTask, fakeTask]);

        final captured =
            verifyInOrder([
                  () => mockConfigLoader.loadTaskConfig(task1Provider.name),
                  () => mockRef.read(task1Provider),
                  () => mockConfigLoader.loadTaskConfig(task2Provider.name),
                  () => mockRef.read<FakeTaskBase>(captureAny()),
                ]).captured[3].single
                as Provider<FakeTaskBase>;
        verifyNoMoreInteractions(mockConfigLoader);
        verifyNoMoreInteractions(mockRef);

        expect(captured.name, task2Provider.name);
        expect(captured.argument, isEmpty);
      });
    });
  });
}
