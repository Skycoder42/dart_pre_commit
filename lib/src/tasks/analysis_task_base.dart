import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as path;

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/file_resolver.dart';
import '../util/logger.dart';
import '../util/program_runner.dart';
import 'models/analyze/analyze_result.dart';
import 'models/analyze/diagnostic.dart';

part 'analysis_task_base.freezed.dart';
part 'analysis_task_base.g.dart';

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
sealed class AnalysisConfig with _$AnalysisConfig {
  /// @nodoc
  // ignore: invalid_annotation_target
  @JsonSerializable(
    anyMap: true,
    checked: true,
    disallowUnrecognizedKeys: true,
  )
  const factory AnalysisConfig({
    // ignore: invalid_annotation_target
    @JsonKey(name: 'error-level')
    @Default(AnalyzeErrorLevel.info)
    AnalyzeErrorLevel errorLevel,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'ignore-unstaged-files')
    @Default(false)
    bool ignoreUnstagedFiles,
  }) = _AnalysisConfig;

  /// @nodoc
  factory AnalysisConfig.fromJson(Map<String, dynamic> json) =>
      _$AnalysisConfigFromJson(json);
}

/// @nodoc
@internal
abstract base class AnalysisTaskBase with PatternTaskMixin implements RepoTask {
  final ProgramRunner _programRunner;
  final FileResolver _fileResolver;
  final TaskLogger _logger;
  final AnalysisConfig _config;

  /// @nodoc
  const AnalysisTaskBase({
    required ProgramRunner programRunner,
    required FileResolver fileResolver,
    required TaskLogger logger,
    required AnalysisConfig config,
  })  : _programRunner = programRunner,
        _fileResolver = fileResolver,
        _logger = logger,
        _config = config;

  @override
  Pattern get filePattern => RegExp(r'^(?:pubspec\.ya?ml|.*\.dart)$');

  @override
  bool get callForEmptyEntries => true;

  @protected
  Iterable<String> get analysisCommand;

  @override
  Future<TaskResult> call(Iterable<RepoEntry> entries) async {
    final exitCode = await _scanAll(entries.toList());
    return exitCode != 0 ? TaskResult.rejected : TaskResult.accepted;
  }

  Future<int> _scanAll(List<RepoEntry> entries) async {
    final (exitCode, result) = await _runAnalyze();
    var lintCnt = 0;
    var ignoreCnt = 0;
    for (final diagnostic in result.diagnostics) {
      await _logDiagnostic(diagnostic);
      ++lintCnt;

      if (_shouldIgnore(diagnostic, entries)) {
        ++ignoreCnt;
        continue;
      }
    }

    if (ignoreCnt > 0 && ignoreCnt == lintCnt) {
      _logger.info('$lintCnt issue(s) found, but none are in staged files.');
      return 0;
    } else if (ignoreCnt > 0) {
      _logger.info(
        '$lintCnt issue(s) found, $ignoreCnt of those are in unstaged files.',
      );
    } else {
      _logger.info('$lintCnt issue(s) found.');
    }

    return exitCode;
  }

  Future<(int, AnalyzeResult)> _runAnalyze() async {
    var exitCode = -1;
    final jsonString = await _programRunner
        .stream(
          'dart',
          [
            ...analysisCommand,
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

  bool _shouldIgnore(Diagnostic diagnostic, List<RepoEntry> entries) {
    if (!_config.ignoreUnstagedFiles) {
      return false;
    }
    return !entries.any(
      (e) => path.equals(e.file.path, diagnostic.location.file),
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
