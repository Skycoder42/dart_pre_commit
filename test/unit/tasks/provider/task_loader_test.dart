// import 'package:dart_pre_commit/src/config/config_loader.dart';
// import 'package:dart_pre_commit/src/task_base.dart';
// import 'package:dart_pre_commit/src/tasks/provider/task_loader.dart';
// import 'package:dart_pre_commit/src/tasks/provider/task_provider.dart';
// import 'package:mocktail/mocktail.dart';
// import 'package:riverpod/riverpod.dart';
// import 'package:test/test.dart';
// import 'package:yaml/yaml.dart';

// class MockConfigLoader extends Mock implements ConfigLoader {}

// // Remove MockRef entirely and use ProviderContainer
// class FakeTaskBase extends Fake implements TaskBase {
//   Map<String, String>? config;
// }

// final task1Provider = TaskProvider('task-1', (ref) => FakeTaskBase());

// final task2Provider = TaskProvider.configurable(
//   'task-2',
//   (json) => json.cast<String, String>(),
//   (ref, arg) => FakeTaskBase()..config = arg,
// );

// void main() {
//   setUpAll(() {
//     registerFallbackValue(task1Provider);
//   });

//   group('$TaskLoader', () {
//     final mockConfigLoader = MockConfigLoader();
//     late ProviderContainer container;
//     late TaskLoader sut;
//     final fakeTask = FakeTaskBase();

//     setUp(() {
//       reset(mockConfigLoader);

//       // Create a ProviderContainer with overrides
//       container = ProviderContainer(
//         overrides: [
//           // Override the providers to return your fake task
//           task1Provider.provider.overrideWithValue(fakeTask),
//           // task2Provider.fromJson. provider.overrideWith((ref, arg) => FakeTaskBase()..config = arg),
//         ],
//       );

//       // Use the container as the ref
//       sut = TaskLoader(ref: container, configLoader: mockConfigLoader);
//     });

//     tearDown(() {
//       container.dispose();
//     });

//     group('loadTasks', () {
//       test('returns single, non configured task', () {
//         when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(YamlMap());

//         sut.registerTask(task1Provider);

//         final tasks = sut.loadTasks();

//         expect(tasks, [fakeTask]);

//         verify(() => mockConfigLoader.loadTaskConfig(task1Provider.name));
//         verifyNoMoreInteractions(mockConfigLoader);
//       });

//       test('registerTask passes enabledByDefault to config loader', () {
//         when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(null);

//         sut.registerTask(task1Provider, enabledByDefault: false);

//         final tasks = sut.loadTasks();

//         expect(tasks, isEmpty);

//         verify(() => mockConfigLoader.loadTaskConfig(
//           task1Provider.name,
//           enabledByDefault: false,
//         ));
//         verifyNoMoreInteractions(mockConfigLoader);
//       });

//       test('returns empty list if single task is disabled', () {
//         when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(null);

//         sut.registerTask(task1Provider);

//         final tasks = sut.loadTasks();

//         expect(tasks, isEmpty);

//         verify(() => mockConfigLoader.loadTaskConfig(task1Provider.name));
//         verifyNoMoreInteractions(mockConfigLoader);
//       });

//       test('returns single, configured task', () {
//         when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(YamlMap());

//         sut.registerConfigurableTask(task2Provider);

//         final tasks = sut.loadTasks();

//         expect(tasks.length, 1);
//         expect(tasks.first, isA<FakeTaskBase>());

//         verify(() => mockConfigLoader.loadTaskConfig(task2Provider.name));
//         verifyNoMoreInteractions(mockConfigLoader);
//       });

//       test('registerConfigurableTask passes enabledByDefault to config loader', () {
//         when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(null);

//         sut.registerConfigurableTask(task2Provider, enabledByDefault: false);

//         final tasks = sut.loadTasks();

//         expect(tasks, isEmpty);

//         verify(() => mockConfigLoader.loadTaskConfig(
//           task2Provider.name,
//           enabledByDefault: false,
//         ));
//         verifyNoMoreInteractions(mockConfigLoader);
//       });

//       test('returns single, configured task with custom config', () {
//         const testMap = <String, String>{'key1': 'value1', 'key2': 'value2'};
//         when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(YamlMap.wrap(testMap));

//         sut.registerConfigurableTask(task2Provider);

//         final tasks = sut.loadTasks();

//         expect(tasks.length, 1);
//         expect(tasks.first, isA<FakeTaskBase>());
//         expect(tasks.first, testMap);

//         verify(() => mockConfigLoader.loadTaskConfig(task2Provider.name));
//         verifyNoMoreInteractions(mockConfigLoader);
//       });

//       test('returns empty list if configured task is disabled', () {
//         when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(null);

//         sut.registerConfigurableTask(task2Provider);

//         final tasks = sut.loadTasks();

//         expect(tasks, isEmpty);

//         verify(() => mockConfigLoader.loadTaskConfig(task2Provider.name));
//         verifyNoMoreInteractions(mockConfigLoader);
//       });

//       test('returns all enabled tasks', () {
//         when(() => mockConfigLoader.loadTaskConfig(any())).thenReturn(YamlMap());

//         sut
//           ..registerTask(task1Provider)
//           ..registerConfigurableTask(task2Provider);

//         final tasks = sut.loadTasks();

//         expect(tasks.length, 2);

// ignore_for_file: lines_longer_than_80_chars

//         verifyInOrder([
//           () => mockConfigLoader.loadTaskConfig(task1Provider.name),
//           () => mockConfigLoader.loadTaskConfig(task2Provider.name),
//         ]);
//         verifyNoMoreInteractions(mockConfigLoader);
//       });
//     });
//   });
// }
