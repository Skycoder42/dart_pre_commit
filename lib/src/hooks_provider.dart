import 'dart:io';

import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:dart_pre_commit/src/console_logger.dart';
import 'package:riverpod/all.dart'; // ignore: import_of_legacy_library_into_null_safe

import 'analyze_task.dart';
import 'file_resolver.dart';
import 'fix_imports_task.dart';
import 'format_task.dart';
import 'hooks.dart';
import 'program_runner.dart';
import 'pull_up_dependencies_task.dart';
import 'simple_logger.dart';

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
  static AutoDisposeFutureProviderFamily<Hooks, HooksConfig> get hookProvider =>
      HooksProviderInternal.hookProvider;
}

class HooksProviderInternal {
  static final consoleLoggerProvider = Provider<Logger>(
    (ref) => ConsoleLogger(),
  );

  static final simpleLoggerProvider = Provider<Logger>(
    (ref) => SimpleLogger(),
  );

  static Provider<Logger> get loggerProvider =>
      stdout.hasTerminal && stdout.supportsAnsiEscapes
          ? consoleLoggerProvider
          : simpleLoggerProvider;

  static final taskLoggerProvider = Provider<TaskLogger>(
    (ref) => ref.watch(loggerProvider),
  );

  static final fileResolverProvider = Provider(
    (ref) => FileResolver(),
  );

  static final programRunnerProvider = Provider(
    (ref) => ProgramRunner(
      logger: ref.watch(taskLoggerProvider),
    ),
  );

  static final fixImportsProvider = FutureProvider(
    (ref) => FixImportsTask.current(),
  );

  static final formatProvider = Provider(
    (ref) => FormatTask(
      programRunner: ref.watch(programRunnerProvider),
    ),
  );

  static final analyzeProvider = Provider(
    (ref) => AnalyzeTask(
      fileResolver: ref.watch(fileResolverProvider),
      programRunner: ref.watch(programRunnerProvider),
      logger: ref.watch(taskLoggerProvider),
    ),
  );

  static final pullUpDependenciesProvider = Provider(
    (ref) => PullUpDependenciesTask(
      fileResolver: ref.watch(fileResolverProvider),
      programRunner: ref.watch(programRunnerProvider),
      logger: ref.watch(taskLoggerProvider),
    ),
  );

  static final hookProvider = FutureProvider.family.autoDispose(
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
