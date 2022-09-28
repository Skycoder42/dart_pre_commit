import 'package:dart_pre_commit/src/hooks_provider.dart';
import 'package:dart_pre_commit/src/tasks/analyze_task.dart';
import 'package:dart_pre_commit/src/tasks/flutter_compat_task.dart';
import 'package:dart_pre_commit/src/tasks/format_task.dart';
import 'package:dart_pre_commit/src/tasks/lib_export_task.dart';
import 'package:dart_pre_commit/src/tasks/outdated_task.dart';
import 'package:dart_pre_commit/src/tasks/pull_up_dependencies_task.dart';
import 'package:dart_pre_commit/src/tasks/test_import_task.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/program_runner.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

class MockLogger extends Mock implements Logger {}

class MockFileResolver extends Mock implements FileResolver {}

class MockProgramRunner extends Mock implements ProgramRunner {}

class MockFormatTask extends Mock implements FormatTask {}

class MockAnalyzeTask extends Mock implements AnalyzeTask {}

class MockTestImportTask extends Mock implements TestImportTask {}

class MockLibExportTask extends Mock implements LibExportTask {}

class MockOutdatedTask extends Mock implements OutdatedTask {
  @override
  late OutdatedConfig config;
}

class MockPullUpDependenciesTask extends Mock
    implements PullUpDependenciesTask {
  @override
  late PullUpDependenciesConfig config;
}

class MockFlutterCompatTask extends Mock implements FlutterCompatTask {}

void main() {
  final mockLogger = MockLogger();
  final mockResolver = MockFileResolver();
  final mockRunner = MockProgramRunner();
  final mockFormat = MockFormatTask();
  final mockAnalyze = MockAnalyzeTask();
  final mockTestImport = MockTestImportTask();
  final mockLibExport = MockLibExportTask();
  final mockOutdated = MockOutdatedTask();
  final mockPullUp = MockPullUpDependenciesTask();
  final mockFlutterCompat = MockFlutterCompatTask();

  ProviderContainer createIoc() => ProviderContainer(
        overrides: [
          loggerProvider.overrideWithValue(mockLogger),
          fileResolverProvider.overrideWithValue(mockResolver),
          programRunnerProvider.overrideWithValue(mockRunner),
          formatTaskProvider.overrideWithValue(mockFormat),
          analyzeTaskProvider.overrideWithValue(mockAnalyze),
          testImportTaskProvider.overrideWithValue(mockTestImport),
          libExportTaskProvider.overrideWithValue(mockLibExport),
          outdatedTaskProvider.overrideWithProvider(
            Provider.family(
              (ref, OutdatedConfig config) =>
                  // ignore: unnecessary_cast
                  (mockOutdated..config = config) as OutdatedTask,
            ),
          ),
          pullUpDependenciesTaskProvider.overrideWithProvider(
            Provider.family(
              (ref, PullUpDependenciesConfig config) =>
                  // ignore: unnecessary_cast
                  (mockPullUp..config = config) as PullUpDependenciesTask,
            ),
          ),
          flutterCompatTaskProvider.overrideWithValue(mockFlutterCompat),
        ],
      );

  setUp(() {
    reset(mockFormat);
    reset(mockAnalyze);
    reset(mockPullUp);

    when(() => mockFormat.taskName).thenReturn('format');
    when(() => mockAnalyze.taskName).thenReturn('analyze');
    when(() => mockTestImport.taskName).thenReturn('testImports');
    when(() => mockLibExport.taskName).thenReturn('libExports');
    when(() => mockOutdated.taskName)
        .thenAnswer((i) => 'outdated:${mockOutdated.config}');
    when(() => mockPullUp.taskName)
        .thenAnswer((i) => 'pullUpDependencies:${mockPullUp.config}');
    when(() => mockFlutterCompat.taskName).thenReturn('flutterCompat');
  });

  testData<Tuple3<HooksConfig, Iterable<String>, bool>>(
    'config loads correct hooks',
    [
      const Tuple3(HooksConfig(), [], false),
      const Tuple3(HooksConfig(format: true), ['format'], false),
      const Tuple3(HooksConfig(analyze: true), ['analyze'], false),
      const Tuple3(HooksConfig(testImports: true), ['testImports'], false),
      const Tuple3(HooksConfig(libExports: true), ['libExports'], false),
      const Tuple3(
        HooksConfig(flutterCompat: true),
        ['flutterCompat'],
        false,
      ),
      for (final level in OutdatedLevel.values)
        Tuple3(
          HooksConfig(outdated: OutdatedConfig(level: level)),
          ['outdated:${OutdatedConfig(level: level)}'],
          false,
        ),
      Tuple3(
        const HooksConfig(pullUpDependencies: PullUpDependenciesConfig()),
        ['pullUpDependencies:${const PullUpDependenciesConfig()}'],
        false,
      ),
      const Tuple3(HooksConfig(continueOnRejected: true), [], true),
      Tuple3(
        const HooksConfig(
          format: true,
          analyze: true,
          pullUpDependencies: PullUpDependenciesConfig(),
          continueOnRejected: true,
        ),
        [
          'format',
          'analyze',
          'pullUpDependencies:${const PullUpDependenciesConfig()}',
        ],
        true,
      ),
    ],
    (fixture) async {
      final ioc = createIoc();
      final hooks = ioc.read(HooksProvider.hookProvider(fixture.item1));
      expect(hooks.tasks, fixture.item2);
      expect(hooks.continueOnRejected, fixture.item3);
    },
  );
}
