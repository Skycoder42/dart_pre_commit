import 'dart:convert';
import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as path;

import 'file_resolver.dart';
import 'logger.dart';
import 'models/workspace.dart';
import 'program_runner.dart';

@internal
@injectable
class LockfileResolver {
  final ProgramRunner _programRunner;
  final FileResolver _fileResolver;
  final TaskLogger _logger;

  const LockfileResolver(this._programRunner, this._fileResolver, this._logger);

  Future<File?> findWorkspaceLockfile() async {
    final workspace = await _programRunner
        .stream('dart', [
          'pub',
          'workspace',
          'list',
          '--json',
        ], runInShell: true)
        .transform(json.decoder)
        .cast<Map<String, dynamic>>()
        .map(Workspace.fromJson)
        .single;

    for (final package in workspace.packages) {
      final lockFile = _fileResolver.file(
        path.join(package.path, 'pubspec.lock'),
      );
      if (lockFile.existsSync()) {
        _logger.debug('Detected workspace lockfile as: ${lockFile.path}');
        return lockFile;
      }
    }

    _logger.error('Failed to find pubspec.lock in workspace');
    return null;
  }
}
