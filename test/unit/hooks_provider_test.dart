import 'package:dart_pre_commit/src/hooks_provider.dart';
import 'package:dart_pre_commit/src/tasks/analyze_task.dart';
import 'package:dart_pre_commit/src/tasks/format_task.dart';
import 'package:dart_pre_commit/src/tasks/pull_up_dependencies_task.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../test_with_data.dart';

class MockLogger extends Mock implements Logger {}

class MockFileResolver extends Mock implements FileResolver {}

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockFormatTask extends Mock implements FormatTask {}

class MockAnalyzeTask extends Mock implements AnalyzeTask {}

class MockPullUpDependenciesTask extends Mock
    implements PullUpDependenciesTask {}

void main() {
  final mockLogger = MockLogger();
  final mockResolver = MockFileResolver();
  final mockRunner = MockProgramRunner();
  final mockFormat = MockFormatTask();
  final mockAnalayze = MockAnalyzeTask();
  final mockPullUp = MockPullUpDependenciesTask();

  ProviderContainer ioc() => ProviderContainer(
        overrides: [
          HooksProviderInternal.loggerProvider.overrideWithValue(mockLogger),
          HooksProviderInternal.fileResolverProvider
              .overrideWithValue(mockResolver),
          HooksProviderInternal.programRunnerProvider
              .overrideWithValue(mockRunner),
          HooksProviderInternal.formatProvider.overrideWithValue(mockFormat),
          HooksProviderInternal.analyzeProvider.overrideWithValue(mockAnalayze),
          HooksProviderInternal.pullUpDependenciesProvider
              .overrideWithValue(mockPullUp),
        ],
      );

  setUp(() {
    reset(mockFormat);
    reset(mockAnalayze);
    reset(mockPullUp);

    when(() => mockFormat.taskName).thenReturn('mockFormat');
    when(() => mockAnalayze.taskName).thenReturn('mockAnalayze');
    when(() => mockPullUp.taskName).thenReturn('mockPullUp');
  });

  testWithData<Tuple3<HooksConfig, Iterable<String>, bool>>(
    'config loads correct hooks',
    const [
      Tuple3(HooksConfig(), [], false),
      Tuple3(HooksConfig(format: true), ['mockFormat'], false),
      Tuple3(HooksConfig(analyze: true), ['mockAnalayze'], false),
      Tuple3(HooksConfig(pullUpDependencies: true), ['mockPullUp'], false),
      Tuple3(HooksConfig(continueOnRejected: true), [], true),
      Tuple3(
        HooksConfig(
          format: true,
          analyze: true,
          pullUpDependencies: true,
          continueOnRejected: true,
        ),
        [
          'mockFormat',
          'mockAnalayze',
          'mockPullUp',
        ],
        true,
      ),
    ],
    (fixture) async {
      final _ioc = ioc();
      final hooks = await _ioc.read(
        HooksProvider.hookProvider(fixture.item1).future,
      );
      expect(hooks.tasks, fixture.item2);
      expect(hooks.continueOnRejected, fixture.item3);
    },
  );
}
