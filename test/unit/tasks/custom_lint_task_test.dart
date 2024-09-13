import 'package:dart_pre_commit/src/tasks/analysis_task_base.dart';
import 'package:dart_pre_commit/src/tasks/custom_lint_task.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockFileResolver extends Mock implements FileResolver {}

class MockTaskLogger extends Mock implements TaskLogger {}

void main() {
  group('$CustomLintTask', () {
    final mockLogger = MockTaskLogger();
    final mockRunner = MockProgramRunner();
    final mockResolver = MockFileResolver();

    late CustomLintTask sut;

    setUp(() {
      reset(mockLogger);
      reset(mockRunner);
      reset(mockResolver);

      sut = CustomLintTask(
        logger: mockLogger,
        programRunner: mockRunner,
        fileResolver: mockResolver,
        config: const AnalysisConfig(),
      );
    });

    test('returns correct task name and analysis command', () {
      expect(sut.taskName, 'custom-lint');
      expect(sut.analysisCommand, ['run', 'custom_lint']);
    });
  });
}
