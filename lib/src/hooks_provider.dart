import 'package:riverpod/all.dart'; // ignore: import_of_legacy_library_into_null_safe

import 'analyze_task.dart';
import 'file_resolver.dart';
import 'fix_imports_task.dart';
import 'format_task.dart';
import 'hooks.dart';
import 'logger.dart';
import 'program_runner.dart';
import 'pull_up_dependencies_task.dart';

class HooksConfig {
  final bool fixImports;
  final bool format;
  final bool analyze;
  final bool pullUpDependencies;
  final bool continueOnRejected;

  const HooksConfig({
    this.fixImports = false,
    this.format = false,
    this.analyze = false,
    this.pullUpDependencies = false,
    this.continueOnRejected = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! HooksConfig) {
      return false;
    }
    return fixImports == other.fixImports &&
        format == other.format &&
        analyze == other.analyze &&
        pullUpDependencies == other.pullUpDependencies &&
        continueOnRejected == other.continueOnRejected;
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      fixImports.hashCode ^
      format.hashCode ^
      analyze.hashCode ^
      pullUpDependencies.hashCode ^
      continueOnRejected.hashCode;
}

class HooksProvider {
  static FutureProviderFamily<Hooks, HooksConfig> get hookProvider =>
      HooksProviderInternal.hookProvider;
}

class HooksProviderInternal {
  static final loggerProvider = Provider(
    (ref) => const Logger.standard(),
  );

  static final fileResolverProvider = Provider(
    (ref) => FileResolver(),
  );

  static final programRunnerProvider = Provider(
    (ref) => ProgramRunner(ref.watch(loggerProvider)),
  );

  static final fixImportsProvider = FutureProvider(
    (ref) => FixImportsTask.current(),
  );

  static final formatProvider = Provider(
    (ref) => FormatTask(ref.watch(programRunnerProvider)),
  );

  static final analyzeProvider = Provider(
    (ref) => AnalyzeTask(
      logger: ref.watch(loggerProvider),
      fileResolver: ref.watch(fileResolverProvider),
      programRunner: ref.watch(programRunnerProvider),
    ),
  );

  static final pullUpDependenciesProvider = Provider(
    (ref) => PullUpDependenciesTask(
      logger: ref.watch(loggerProvider),
      fileResolver: ref.watch(fileResolverProvider),
      programRunner: ref.watch(programRunnerProvider),
    ),
  );

  static final hookProvider = FutureProvider.family(
    (ref, HooksConfig param) async => Hooks(
      logger: ref.watch(loggerProvider),
      resolver: ref.watch(fileResolverProvider),
      programRunner: ref.watch(programRunnerProvider),
      continueOnRejected: param.continueOnRejected,
      tasks: [
        if (param.fixImports) await ref.watch(fixImportsProvider.future),
        if (param.format) ref.watch(formatProvider),
        if (param.analyze) ref.watch(analyzeProvider),
        if (param.pullUpDependencies) ref.watch(pullUpDependenciesProvider),
      ],
    ),
  );
}
