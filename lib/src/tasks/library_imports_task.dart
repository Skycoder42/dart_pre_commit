import 'dart:convert';
import 'dart:io';

import 'package:dart_pre_commit/src/repo_entry.dart';
import 'package:dart_pre_commit/src/util/file_resolver.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

import '../task_base.dart';

/// A task that scans dart files for imports of top level library files.
///
/// The imports of each file are scanned for imports that point to a top level
/// library file. If one is found within the lib/src or test dirs, it is logged
/// and this task fails with [TaskResult.rejected]. If all imports are ok, the
/// task returns [TaskResult.accepted].
///
/// {@category tasks}
class LibraryImportsTask implements FileTask {
  /// The name if the package that is beeing scanned.
  ///
  /// Must be the same as declared in the `pubspec.yaml`.
  final String packageName;

  /// The [FileResolver] instance used by this task.
  final FileResolver fileResolver;

  /// The [TaskLogger] instance used by this task.
  final TaskLogger logger;

  /// Default Constructor.
  ///
  /// See [LibraryImportsTask.current] for a simply instanciation.
  const LibraryImportsTask({
    required this.packageName,
    required this.fileResolver,
    required this.logger,
  });

  /// Creates a [LibraryImportsTask] based on the current repository.
  ///
  /// This method looks and the `pubspec.yaml` in the current directory and uses
  /// it to figure out the [packageName]. The [fileResolver] and [logger] is
  /// passed to [this.fileResolver] and [this.logger].
  static Future<LibraryImportsTask> current({
    required FileResolver fileResolver,
    required TaskLogger logger,
  }) async {
    final pubspecFile = File('pubspec.yaml');
    final yamlData = loadYamlDocument(
      await pubspecFile.readAsString(),
      sourceUrl: pubspecFile.uri,
    ).contents as YamlMap;

    return LibraryImportsTask(
      packageName: yamlData.value['name'] as String,
      fileResolver: fileResolver,
      logger: logger,
    );
  }

  @override
  String get taskName => 'library-imports';

  @override
  Pattern get filePattern => RegExp(r'^(?:lib[\/\\]src|test)[\/\\].*\.dart$');

  @override
  Future<TaskResult> call(RepoEntry entry) async {
    final libDir = Directory('lib');
    final srcDir = Directory(join(libDir.path, 'src'));

    final absoluteImportRegex = RegExp(
      '''^\\s*import\\s*['"](package:${RegExp.escape(packageName)}\\/(?!src\\/)[^'"]*)['"].*\$''',
    );
    final relativeImportRegex = RegExp(
      r'''^\s*import\s*['"](?!package:|dart:)([^'"]+)['"].*$''',
    );

    final lines = entry.file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    var foundImports = false;
    await for (final line in lines) {
      final absoluteMatch = absoluteImportRegex.firstMatch(line);
      if (absoluteMatch != null) {
        logger.info(
          'Found absolute import of non-src library: ${absoluteMatch[1]}',
        );
        foundImports = true;
        continue;
      }

      final relativeMatch = relativeImportRegex.firstMatch(line);
      if (relativeMatch != null) {
        final importedPath = relativeMatch[1]!;
        final resolvedPath = await fileResolver.resolve(
          join(entry.file.parent.path, importedPath),
        );

        if (isWithin(libDir.path, resolvedPath) &&
            !isWithin(srcDir.path, resolvedPath)) {
          logger.info(
            'Found relative import of non-src library: $importedPath',
          );
          foundImports = true;
          continue;
        }
      }
    }

    if (foundImports) {
      return TaskResult.rejected;
    } else {
      logger.debug('No library imports found');
      return TaskResult.accepted;
    }
  }
}
