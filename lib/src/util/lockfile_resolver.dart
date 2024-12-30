import 'dart:convert';
import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod/riverpod.dart';

import 'file_resolver.dart';
import 'logger.dart';
import 'models/workspace.dart';
import 'program_runner.dart';

// coverage:ignore-start
/// @nodoc
@internal
final lockfileResolverProvider = Provider(
  (ref) => LockfileResolver(
    programRunner: ref.watch(programRunnerProvider),
    fileResolver: ref.watch(fileResolverProvider),
    logger: ref.watch(taskLoggerProvider),
  ),
);
// coverage:ignore-end

@internal
class LockfileResolver {
  final ProgramRunner _programRunner;
  final FileResolver _fileResolver;
  final TaskLogger _logger;

  LockfileResolver({
    required ProgramRunner programRunner,
    required FileResolver fileResolver,
    required TaskLogger logger,
  })  : _programRunner = programRunner,
        _fileResolver = fileResolver,
        _logger = logger;

  Future<File?> findWorkspaceLockfile() async {
    final workspace = await _programRunner
        .stream(
          'dart',
          ['pub', 'workspace', 'list', '--json'],
          runInShell: true,
        )
        .transform(json.decoder)
        .cast<Map<String, dynamic>>()
        .map(Workspace.fromJson)
        .single;

    for (final package in workspace.packages) {
      final lockFile =
          _fileResolver.file(path.join(package.path, 'pubspec.lock'));
      if (lockFile.existsSync()) {
        _logger.debug('Detected workspace lockfile as: ${lockFile.path}');
        return lockFile;
      }
    }

    _logger.error('Failed to find pubspec.lock in workspace');
    return null;
  }
}
