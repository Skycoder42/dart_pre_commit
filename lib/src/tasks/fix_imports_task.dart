import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart'; // ignore: import_of_legacy_library_into_null_safe
import 'package:crypto/crypto.dart'; // ignore: import_of_legacy_library_into_null_safe
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/logger.dart';

/// A task that scans dart files for unclean imports and fixes them.
///
/// This task consists of two steps, wich are run on all staged dart files:
/// 1. Make absolute package imports relative
/// 2. Organize imports
///
/// The first step simply checks if any library imports another library from the
/// same package via an absolute package import. If that is the case, the import
/// is simply replaced by a relative one.
///
/// The second step collects all imports of the file and the sorts them. They
/// are grouped into dart imports, package imports and relative imports, each
/// group seperated by a newline and the internally sorted alphabetically.
///
/// If any of these steps had to modify the file, it saves the changes to the
/// file and returns a [TaskResult.modified] result.
///
/// {@category tasks}
class FixImportsTask implements FileTask {
  /// The name if the package that is beeing scanned.
  ///
  /// Must be the same as declared in the `pubspec.yaml`.
  final String packageName;

  /// The path to the lib folder in this package.
  ///
  /// This is almost always simply `'lib'`.
  final Directory libDir;

  /// The [TaskLogger] instance used by this task.
  final TaskLogger logger;

  /// Default Constructor.
  ///
  /// See [FixImportsTask.current()] for a simply instanciation.
  const FixImportsTask({
    required this.packageName,
    required this.libDir,
    required this.logger,
  });

  /// Creates a [FixImportsTask] based on the current repository.
  ///
  /// This method looks and the `pubspec.yaml` in the current directory and uses
  /// it to figure out the [packageName] and [libDir]. The [logger] is passed to
  /// [this.logger].
  static Future<FixImportsTask> current({
    required TaskLogger logger,
  }) async {
    final pubspecFile = File('pubspec.yaml');
    final yamlData = loadYamlDocument(
      await pubspecFile.readAsString(),
      sourceUrl: pubspecFile.uri,
    ).contents as YamlMap;

    return FixImportsTask(
      libDir: Directory('lib'),
      packageName: yamlData.value['name'] as String,
      logger: logger,
    );
  }

  @override
  String get taskName => 'fix-imports';

  @override
  Pattern get filePattern => RegExp(r'^.*\.dart$');

  @override
  Future<TaskResult> call(RepoEntry entry) async {
    final inDigest = AccumulatorSink<Digest>();
    final outDigest = AccumulatorSink<Digest>();
    final result = await Stream.fromFuture(entry.file.readAsString())
        .transform(const LineSplitter())
        .shaSum(inDigest)
        .relativize(
          packageName: packageName,
          file: entry.file,
          libDir: libDir,
          logger: logger,
        )
        .organizeImports(logger)
        .shaSum(outDigest)
        .withNewlines()
        .join();

    if (inDigest.events.single != outDigest.events.single) {
      logger.debug('File has been modified, writing changes...');
      await entry.file.writeAsString(result);
      logger.debug('Write successful');
      return TaskResult.modified;
    } else {
      logger.debug('No imports modified, keeping file as is');
      return TaskResult.accepted;
    }
  }
}

class _SourceImport implements Comparable<_SourceImport> {
  final String import;
  final List<String> prefixLines;
  final List<String> suffixLines;

  _SourceImport(
    this.import, {
    List<String>? prefixLines,
    List<String>? suffixLines,
  })  : prefixLines = prefixLines ?? [],
        suffixLines = suffixLines ?? [];

  Iterable<String> get lines => [...prefixLines, import, ...suffixLines];

  @override
  int compareTo(_SourceImport other) => import.compareTo(other.import);
}

extension _ImportFixExtensions on Stream<String> {
  Stream<String> shaSum(AccumulatorSink<Digest> sink) async* {
    final input = sha512.startChunkedConversion(sink);
    try {
      await for (final part in this) {
        input.add(utf8.encode(part));
        yield part;
      }
    } finally {
      input.close();
    }
  }

  Stream<String> relativize({
    required String packageName,
    required File file,
    required Directory libDir,
    required TaskLogger logger,
  }) async* {
    if (!isWithin(libDir.path, file.path)) {
      yield* this;
      return;
    }

    final regexp = RegExp(
      """^\\s*import\\s*(['"])package:${RegExp.escape(packageName)}\\/([^'"]*)['"](.*)\$""",
    );

    await for (final line in this) {
      final trimmedLine = line.trim();
      final match = regexp.firstMatch(trimmedLine);
      if (match != null) {
        logger.debug('Relativizing $trimmedLine');
        final quote = match[1];
        final importPath = match[2];
        final postfix = match[3];
        final relativeImport = relative(
          join('lib', importPath),
          from: file.parent.path,
        ).replaceAll('\\', '/');

        yield 'import $quote$relativeImport$quote$postfix';
      } else {
        yield line;
      }
    }
  }

  Stream<String> organizeImports(TaskLogger logger) async* {
    const baseRegExpPrefix = r'''^\s*import\s*(?:"|')''';
    const baseRegExpSuffix = r'''[^'"]+(?:"|')([^;\/]*;)?.*?$''';

    final importGroups = <RegExp, List<_SourceImport>>{
      RegExp('${baseRegExpPrefix}dart:$baseRegExpSuffix'): [],
      RegExp('${baseRegExpPrefix}package:$baseRegExpSuffix'): [],
      RegExp('$baseRegExpPrefix(?!package:|dart:)$baseRegExpSuffix'): [],
    };
    final openLineRegExp = RegExp(r'^[^\/]+;.*$');

    final lineCache = <String>[];
    _SourceImport? openImport;

    await for (final line in this) {
      var consumed = false;
      for (final importGroup in importGroups.entries) {
        final match = importGroup.key.firstMatch(line);
        if (match != null) {
          final import = _SourceImport(
            line,
            prefixLines: lineCache
                .where((l) => l.trim().isNotEmpty)
                .toList(growable: false),
          );
          lineCache.clear();
          importGroup.value.add(import);
          openImport = (match[1]?.isEmpty ?? true) ? import : null;
          consumed = true;
          break;
        }
      }
      if (consumed) {
        continue;
      }

      // no match
      if (openImport != null) {
        if (line.trim().isNotEmpty) {
          openImport.suffixLines.add(line);
          if (openLineRegExp.hasMatch(line)) {
            openImport = null;
          }
        }
      } else {
        lineCache.add(line);
      }
    }

    // sort individual imports
    logger.debug('Sorting imports...');
    for (final imports in importGroups.values) {
      imports.sort((a, b) => a.compareTo(b));
      if (imports.isNotEmpty) {
        yield* Stream.fromIterable(imports).expand((i) => i.lines);
        yield '';
      }
    }

    // remove leading/trailing empty lines, print code
    while (lineCache.isNotEmpty && lineCache.first.trim().isEmpty) {
      lineCache.removeAt(0);
    }
    while (lineCache.isNotEmpty && lineCache.last.trim().isEmpty) {
      lineCache.removeLast();
    }
    if (lineCache.isNotEmpty) {
      yield* Stream.fromIterable(lineCache);
    }
  }

  Stream<String> withNewlines() async* {
    await for (final line in this) {
      yield '$line\n';
    }
  }
}
