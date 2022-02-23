import 'package:dart_pre_commit/src/hooks_provider.dart';
import 'package:dart_pre_commit/src/tasks/analyze_task.dart';
import 'package:dart_pre_commit/src/tasks/flutter_compat_task.dart';
import 'package:dart_pre_commit/src/tasks/format_task.dart';
import 'package:dart_pre_commit/src/tasks/outdated_task.dart';
import 'package:dart_pre_commit/src/tasks/pull_up_dependencies_task.dart';
import 'package:dart_pre_commit/src/tasks/test_import_task.dart';
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

class MockTestImportsTask extends Mock implements TestImportTask {}

class MockOutdatedTask extends Mock implements OutdatedTask {
  @override
  late OutdatedLevel outdatedLevel;
}

class MockPullUpDependenciesTask extends Mock
    implements PullUpDependenciesTask {}

class MockFlutterCompatTask extends Mock implements FlutterCompatTask {}

void main() {
  final mockLogger = MockLogger();
  final mockResolver = MockFileResolver();
  final mockRunner = MockProgramRunner();
  final mockFormat = MockFormatTask();
  final mockAnalyze = MockAnalyzeTask();
  final mockTestImports = MockTestImportsTask();
  final mockOutdated = MockOutdatedTask();
  final mockPullUp = MockPullUpDependenciesTask();
  final mockFlutterCompat = MockFlutterCompatTask();

  ProviderContainer ioc() => ProviderContainer(
        overrides: [
          HooksProviderInternal.loggerProvider.overrideWithValue(mockLogger),
          HooksProviderInternal.fileResolverProvider
              .overrideWithValue(mockResolver),
          HooksProviderInternal.programRunnerProvider
              .overrideWithValue(mockRunner),
          HooksProviderInternal.formatProvider.overrideWithValue(mockFormat),
          HooksProviderInternal.analyzeProvider.overrideWithValue(mockAnalyze),
          HooksProviderInternal.testImportProvider
              .overrideWithValue(mockTestImports),
          HooksProviderInternal.outdatedProvider.overrideWithProvider(
            FutureProvider.family(
              (ref, OutdatedLevel level) =>
                  // ignore: unnecessary_cast
                  (mockOutdated..outdatedLevel = level) as OutdatedTask,
            ),
          ),
          HooksProviderInternal.pullUpDependenciesProvider
              .overrideWithValue(mockPullUp),
          HooksProviderInternal.flutterCompatProvider
              .overrideWithValue(mockFlutterCompat),
        ],
      );

  setUp(() {
    reset(mockFormat);
    reset(mockAnalyze);
    reset(mockPullUp);

    when(() => mockFormat.taskName).thenReturn('format');
    when(() => mockAnalyze.taskName).thenReturn('analyze');
    when(() => mockTestImports.taskName).thenReturn('testImports');
    when(() => mockOutdated.taskName)
        .thenAnswer((i) => 'outdated:${mockOutdated.outdatedLevel.name}');
    when(() => mockPullUp.taskName).thenReturn('pullUpDependencies');
    when(() => mockFlutterCompat.taskName).thenReturn('flutterCompat');
  });

  testWithData<Tuple3<HooksConfig, Iterable<String>, bool>>(
    'config loads correct hooks',
    [
      const Tuple3(HooksConfig(), [], false),
      const Tuple3(HooksConfig(format: true), ['format'], false),
      const Tuple3(HooksConfig(analyze: true), ['analyze'], false),
      const Tuple3(HooksConfig(testImports: true), ['testImports'], false),
      const Tuple3(
        HooksConfig(flutterCompat: true),
        ['flutterCompat'],
        false,
      ),
      for (final level in OutdatedLevel.values)
        Tuple3(
          HooksConfig(outdated: level),
          ['outdated:${level.name}'],
          false,
        ),
      const Tuple3(
        HooksConfig(pullUpDependencies: true),
        ['pullUpDependencies'],
        false,
      ),
      const Tuple3(HooksConfig(continueOnRejected: true), [], true),
      const Tuple3(
        HooksConfig(
          format: true,
          analyze: true,
          pullUpDependencies: true,
          continueOnRejected: true,
        ),
        [
          'format',
          'analyze',
          'pullUpDependencies',
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
