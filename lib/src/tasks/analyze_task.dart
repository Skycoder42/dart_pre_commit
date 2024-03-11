import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/file_resolver.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';
import 'models/analyze/analyze_result.dart';
import 'models/analyze/diagnostic.dart';
import 'provider/task_provider.dart';

part 'analyze_task.freezed.dart';
part 'analyze_task.g.dart';

// coverage:ignore-start
/// A riverpod provider for the analyze task.
final analyzeTaskProvider = TaskProvider.configurable(
  AnalyzeTask._taskName,
  AnalyzeConfig.fromJson,
  (ref, config) => AnalyzeTask(
    fileResolver: ref.watch(fileResolverProvider),
    programRunner: ref.watch(programRunnerProvider),
    logger: ref.watch(taskLoggerProvider),
    config: config,
  ),
);
// coverage:ignore-end

/// @nodoc
@internal
enum AnalyzeErrorLevel {
  /// @nodoc
  error(['--no-fatal-warnings']),

  /// @nodoc
  warning(['--fatal-warnings']),

  /// @nodoc
  info(['--fatal-warnings', '--fatal-infos']);

  final List<String> _params;

  /// @nodoc
  const AnalyzeErrorLevel(this._params);
}

/// @nodoc
@internal
@freezed
class AnalyzeConfig with _$AnalyzeConfig {
  /// @nodoc
  // ignore: invalid_annotation_target
  @JsonSerializable(
    anyMap: true,
    checked: true,
    disallowUnrecognizedKeys: true,
  )
  const factory AnalyzeConfig({
    // ignore: invalid_annotation_target
    @JsonKey(name: 'error-level')
    @Default(AnalyzeErrorLevel.info)
    AnalyzeErrorLevel errorLevel,
  }) = _AnalyzeConfig;

  /// @nodoc
  factory AnalyzeConfig.fromJson(Map<String, dynamic> json) =>
      _$AnalyzeConfigFromJson(json);
}

/// @nodoc
@internal
class AnalyzeTask with PatternTaskMixin implements RepoTask {
  static const _taskName = 'analyze';

  final ProgramRunner _programRunner;

  final FileResolver _fileResolver;

  final TaskLogger _logger;

  final AnalyzeConfig _config;

  /// @nodoc
  const AnalyzeTask({
    required ProgramRunner programRunner,
    required FileResolver fileResolver,
    required TaskLogger logger,
    required AnalyzeConfig config,
  })  : _programRunner = programRunner,
        _fileResolver = fileResolver,
        _logger = logger,
        _config = config;

  @override
  String get taskName => _taskName;

  @override
  Pattern get filePattern => RegExp(r'^(?:pubspec\.ya?ml|.*\.dart)$');

  @override
  bool get callForEmptyEntries => false;

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    final exitCode = await _scanAll();
    return exitCode != 0 ? TaskResult.rejected : TaskResult.accepted;
  }

  Future<int> _scanAll() async {
    final (exitCode, result) = await _runAnalyze();
    var lintCnt = 0;
    for (final diagnostic in result.diagnostics) {
      await _logDiagnostic(diagnostic);
      ++lintCnt;
    }
    _logger.info('$lintCnt issue(s) found.');
    return exitCode;
  }

  Future<(int, AnalyzeResult)> _runAnalyze() async {
    var exitCode = -1;
    final jsonString = await _programRunner
        .stream(
          'dart',
          [
            'analyze',
            '--format',
            'json',
            ..._config.errorLevel._params,
          ],
          failOnExit: false,
          exitCodeHandler: (e) => exitCode = e,
        )
        .singleWhere(
          (line) => line.trimLeft().startsWith('{'),
          orElse: () => '',
        );

    if (jsonString.isEmpty) {
      return (exitCode, const AnalyzeResult(version: 1, diagnostics: []));
    }

    return (
      exitCode,
      AnalyzeResult.fromJson(json.decode(jsonString) as Map<String, dynamic>)
    );
  }

  Future<void> _logDiagnostic(Diagnostic diagnostic, [String? path]) async {
    final actualPath =
        path ?? await _fileResolver.resolve(diagnostic.location.file);
    final loggableDiagnostic = diagnostic.copyWith(
      location: diagnostic.location.copyWith(file: actualPath),
    );
    _logger.info('  $loggableDiagnostic');
  }
}
