import 'package:dart_pre_commit/src/config/pubspec_config_loader.dart';
import 'package:dart_pre_commit/src/tasks/analyze_task.dart';
import 'package:dart_pre_commit/src/tasks/custom_lint_task.dart';
import 'package:dart_pre_commit/src/tasks/flutter_compat_task.dart';
import 'package:dart_pre_commit/src/tasks/format_task.dart';
import 'package:dart_pre_commit/src/tasks/osv_scanner_task.dart';
import 'package:dart_pre_commit/src/tasks/outdated_task.dart';
import 'package:dart_pre_commit/src/tasks/provider/default_tasks_loader.dart';
import 'package:dart_pre_commit/src/tasks/provider/task_loader.dart';
import 'package:dart_pre_commit/src/tasks/pull_up_dependencies_task.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_detector.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockPubspecConfigLoader extends Mock implements PubspecConfigLoader {}

class MockProgramDetector extends Mock implements ProgramDetector {}

class MockTaskLoader extends Mock implements TaskLoader {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('$DefaultTasksLoader', () {
    final mockPubspecConfigLoader = MockPubspecConfigLoader();
    final mockProgramDetector = MockProgramDetector();
    final mockTaskLoader = MockTaskLoader();
    final mockLogger = MockLogger();

    late DefaultTasksLoader sut;

    setUp(() {
      reset(mockPubspecConfigLoader);
      reset(mockTaskLoader);
      reset(mockLogger);

      sut = DefaultTasksLoader(
        pubspecConfigLoader: mockPubspecConfigLoader,
        programDetector: mockProgramDetector,
        taskLoader: mockTaskLoader,
        logger: mockLogger,
      );
    });

    group('registerDefaultTasks', () {
      test('registers minimal tasks if extra configs do not apply', () async {
        when(mockPubspecConfigLoader.loadPubspecConfig).thenReturnAsync(
          const PubspecConfig(isFlutterProject: true, isPublished: false),
        );
        when(() => mockProgramDetector.hasProgram(any()))
            .thenReturnAsync(false);

        await sut.registerDefaultTasks();

        verifyInOrder([
          mockPubspecConfigLoader.loadPubspecConfig,
          () => mockTaskLoader.registerConfigurableTask(formatTaskProvider),
          () => mockTaskLoader.registerConfigurableTask(analyzeTaskProvider),
          () => mockTaskLoader.registerTask(customLintTaskProvider),
          () => mockTaskLoader.registerConfigurableTask(outdatedTaskProvider),
          () => mockTaskLoader
              .registerConfigurableTask(pullUpDependenciesTaskProvider),
          () => mockProgramDetector.hasProgram(OsvScannerTask.osvScannerBinary),
        ]);
        verifyNoMoreInteractions(mockPubspecConfigLoader);
        verifyNoMoreInteractions(mockTaskLoader);
      });

      test('registers all tasks if extra configs do apply', () async {
        when(mockPubspecConfigLoader.loadPubspecConfig).thenReturnAsync(
          const PubspecConfig(isFlutterProject: false, isPublished: true),
        );
        when(() => mockProgramDetector.hasProgram(any())).thenReturnAsync(true);

        await sut.registerDefaultTasks();

        verifyInOrder([
          mockPubspecConfigLoader.loadPubspecConfig,
          () => mockTaskLoader.registerConfigurableTask(formatTaskProvider),
          () => mockTaskLoader.registerConfigurableTask(analyzeTaskProvider),
          () => mockTaskLoader.registerTask(customLintTaskProvider),
          () => mockTaskLoader.registerTask(flutterCompatTaskProvider),
          () => mockTaskLoader.registerConfigurableTask(outdatedTaskProvider),
          () => mockTaskLoader
              .registerConfigurableTask(pullUpDependenciesTaskProvider),
          () => mockProgramDetector.hasProgram(OsvScannerTask.osvScannerBinary),
          () => mockTaskLoader.registerTask(osvScannerTaskProvider),
        ]);
        verifyNoMoreInteractions(mockPubspecConfigLoader);
        verifyNoMoreInteractions(mockTaskLoader);
      });
    });
  });
}
