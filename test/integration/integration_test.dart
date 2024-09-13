// ignore_for_file: avoid_print

@Timeout(Duration(minutes: 1))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_pre_commit/src/hooks.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  late Directory testDir;

  Future<void> writeFile(String path, String contents) async {
    final file = File(join(testDir.path, path));
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(contents);
  }

  Future<String> readFile(String path) async =>
      File(join(testDir.path, path)).readAsString();

  Future<int> run(
    String program,
    List<String> arguments, {
    bool failOnError = true,
    void Function(Stream<List<int>>)? onStdout,
  }) async {
    print('\$ $program ${arguments.join(' ')}');
    final proc = await Process.start(
      program,
      arguments,
      workingDirectory: testDir.path,
    );
    if (onStdout != null) {
      onStdout(proc.stdout);
    } else {
      proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((e) => print('OUT: $e'));
    }
    proc.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((e) => print('ERR: $e'));
    final exitCode = await proc.exitCode;
    if (failOnError && exitCode != 0) {
      // ignore: only_throw_errors
      throw 'Failed to run "$program ${arguments.join(' ')}" '
          'with exit code: $exitCode';
    }
    return exitCode;
  }

  Future<void> git(List<String> arguments) async => run('git', arguments);

  Future<int> pub(
    List<String> arguments, {
    bool failOnError = true,
    void Function(Stream<List<int>>)? onStdout,
  }) async =>
      run(
        'dart',
        [
          'pub',
          ...arguments,
        ],
        failOnError: failOnError,
        onStdout: onStdout,
      );

  Future<int> sut(
    String mode, {
    List<String>? arguments,
    Map<String, dynamic>? config,
    bool failOnError = true,
    void Function(String)? onStdout,
  }) async {
    final knownTasks = [
      'format',
      'analyze',
      'custom-lint',
      'flutter-compat',
      'outdated',
      'pull-up-dependencies',
      'osv-scanner',
    ];
    final configEditor = YamlEditor('_placeholder: null');
    for (final task in knownTasks) {
      configEditor.update(
        [task],
        mode == task ? (config ?? true) : false,
      );
    }

    final configFile = File.fromUri(testDir.uri.resolve('config.yaml'));
    await configFile.writeAsString(configEditor.toString());

    return pub(
      [
        'run',
        'dart_pre_commit',
        '--no-ansi',
        '--config-path',
        configFile.path,
        ...?arguments,
      ],
      failOnError: failOnError,
      onStdout: onStdout != null
          ? (s) => s
                  .transform(utf8.decoder)
                  .transform(const LineSplitter())
                  .map((line) {
                print('OUT: $line');
                return line;
              }).listen(onStdout)
          : null,
    );
  }

  setUp(() async {
    // create git repo
    testDir = await Directory.systemTemp.createTemp();
    await git(const ['init']);

    // create files
    await writeFile(
      'pubspec.yaml',
      '''
name: test_project
version: 0.0.1

environment:
  sdk: ^3.0.0

dependencies:
  meta: ^1.8.0
  image: 4.0.0
  mobx: 2.1.0
  dart_pre_commit:
    path: ${Directory.current.path}

dev_dependencies:
  lint: null
  custom_lint: null
  dart_test_tools: '>=5.0.0'
''',
    );

    await writeFile('analysis_options.yaml', '''
analyzer:
  plugins:
    - custom_lint
''');

    await writeFile(
      'bin/format.dart',
      '''
import 'package:test_project/test_project.dart';

void main() {
  final x = 'this is a very very very very very very very very very very very very very very very very very very very very very very long string';
}
''',
    );
    await writeFile(
      'lib/src/analyze.dart',
      '''
void main() {
  var x = 'constant';
}
''',
    );
    await writeFile('lib/test_project.dart', '');
    await writeFile(
      'test/test.dart',
      'import "package:test_project/test_project.dart";',
    );
    await writeFile('stuff.txt', 'not a dart file');

    // init dart
    await pub(const ['get']);
  });

  tearDown(() async {
    await testDir.delete(recursive: true);
  });

  test('format', () async {
    await git(const ['add', 'bin/format.dart']);
    await sut('format');

    final data = await readFile('bin/format.dart');
    expect(
      data,
      '''
import 'package:test_project/test_project.dart';

void main() {
  final x =
      'this is a very very very very very very very very very very very very very very very very very very very very very very long string';
}
''',
    );
  });

  test('analyze', () async {
    await git(const ['add', 'lib/src/analyze.dart']);

    final lines = <String>[];
    final code = await sut(
      'analyze',
      arguments: const ['--detailed-exit-code'],
      failOnError: false,
      onStdout: lines.add,
    );
    expect(
      lines,
      contains(
        '  [INF]   warning - lib${separator}src${separator}analyze.dart:2:7 - '
        "The value of the local variable 'x' isn't used. Try removing the "
        'variable or using it. - unused_local_variable',
      ),
    );
    expect(code, HookResult.rejected.index);
  });

  test(
    'flutter-compat',
    () async {
      printOnFailure('Using PATH: ${Platform.environment['PATH']}');

      await git(const ['add', 'pubspec.yaml']);

      final lines = <String>[];
      final code = await sut(
        'flutter-compat',
        onStdout: lines.add,
      );
      expect(code, HookResult.clean.index);
      expect(
        lines,
        contains(
          startsWith('  [INF] Package test_project is flutter compatible'),
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('pull-up-dependencies', () async {
    await git(const ['add', 'pubspec.lock']);

    final lines = <String>[];
    final code = await sut(
      'pull-up-dependencies',
      arguments: const ['--detailed-exit-code'],
      failOnError: false,
      onStdout: lines.add,
    );
    expect(code, HookResult.rejected.index);
    expect(lines, contains(startsWith('  [INF] meta: ^1.8.0 -> 1.')));
  });

  test('outdated', () async {
    await git(const ['add', 'stuff.txt']);

    final lines = <String>[];
    final code = await sut(
      'outdated',
      arguments: const ['--detailed-exit-code'],
      config: const <String, dynamic>{
        'allowed': ['image'],
      },
      failOnError: false,
      onStdout: lines.add,
    );
    expect(
      lines,
      allOf([
        contains(
          startsWith('  [INF] Required:    mobx: 2.1.0 -> '),
        ),
        contains(
          startsWith('  [WRN] Ignored:     image: 4.0.0 -> '),
        ),
      ]),
    );
    expect(code, HookResult.rejected.index);
  });

  test('custom-lint', () async {
    final lines = <String>[];
    await git(const ['add', 'test/test.dart']);
    final code = await sut(
      'custom-lint',
      arguments: const ['--detailed-exit-code', '-ldebug'],
      failOnError: false,
      onStdout: lines.add,
    );
    expect(code, HookResult.rejected.index);
    expect(
      lines,
      allOf(
        contains(
          '  [INF]   info - lib${separator}src${separator}analyze.dart:1:6 - '
          'The library contains public symbols, but is not exported in any of '
          'the package library files. Exports the library from the package or '
          'make all top level elements non-public. - src_library_not_exported',
        ),
        contains(
          '  [INF]   info - test${separator}test.dart:1:8 - Libraries in '
          'lib/src, test or tool should not import package library files from '
          'lib. Import the library from the src folder instead. - '
          'no_self_package_imports',
        ),
      ),
    );
  });

  test('osv-scanner', () async {
    printOnFailure('Using PATH: ${Platform.environment['PATH']}');

    await writeFile('pubspec_overrides.yaml', '''
dependency_overrides:
  http: 0.13.0
''');
    await pub(['get']);
    await git(const ['add', 'pubspec_overrides.yaml']);

    final lines = <String>[];
    final code = await sut(
      'osv-scanner',
      arguments: const ['--detailed-exit-code', '-ldebug'],
      failOnError: false,
      onStdout: lines.add,
    );
    expect(code, HookResult.rejected.index);
    expect(
      lines,
      allOf(
        contains(
          allOf(
            startsWith('  [WRN] '),
            contains(
              'http@0.13.0 - GHSA-4rgh-jx4f-qfcq: '
              'http before 0.13.3 vulnerable to header injection.',
            ),
          ),
        ),
        contains(
          allOf(
            startsWith('  [ERR] '),
            endsWith('Found 1 security issues in dependencies!'),
          ),
        ),
      ),
    );
  });
}
