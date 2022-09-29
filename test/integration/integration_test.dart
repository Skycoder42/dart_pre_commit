// ignore_for_file: avoid_print
@Timeout(Duration(minutes: 1))

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
    Function(Stream<List<int>>)? onStdout,
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
    Function(Stream<List<int>>)? onStdout,
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
    Function(String)? onStdout,
  }) async {
    final knownTasks = [
      'format',
      'test-imports',
      'analyze',
      'flutter-compat',
      'outdated',
      'pull-up-dependencies',
      'lib-exports',
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
              .listen(onStdout)
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
  sdk: '>=2.12.0-0 <3.0.0'

dependencies:
  meta: ^1.2.0
  mobx: 1.1.0
  rxdart: 0.27.0
  dart_pre_commit:
    path: ${Directory.current.path}

dev_dependencies:
  lint: null
''',
    );

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
        '  [INF]   info - lib${separator}src${separator}analyze.dart:2:7 - '
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
    expect(lines, contains(startsWith('  [INF] meta: ^1.2.0 -> 1.')));
  });

  test('outdated', () async {
    final lines = <String>[];
    final code = await sut(
      'outdated',
      arguments: const ['--detailed-exit-code'],
      config: const <String, dynamic>{
        'allowed': ['rxdart'],
      },
      failOnError: false,
      onStdout: lines.add,
    );
    expect(code, HookResult.rejected.index);
    expect(
      lines,
      allOf([
        contains(
          startsWith('  [INF] Required:    mobx: 1.1.0 -> '),
        ),
        contains(
          startsWith('  [WRN] Ignored:     rxdart: 0.27.0 -> '),
        ),
      ]),
    );
  });

  test('test-imports', () async {
    final lines = <String>[];
    await git(const ['add', 'test/test.dart']);
    final code = await sut(
      'test-imports',
      arguments: const ['--detailed-exit-code', '-ldebug'],
      failOnError: false,
      onStdout: lines.add,
    );
    expect(code, HookResult.rejected.index);
    expect(
      lines,
      contains(
        startsWith('  [ERR] Found self import that is not from src: import '),
      ),
    );
  });

  test('lib-exports', () async {
    final lines = <String>[];
    await git(const ['add', 'lib']);
    final code = await sut(
      'lib-exports',
      arguments: const ['--detailed-exit-code', '-ldebug'],
      failOnError: false,
      onStdout: lines.add,
    );
    expect(code, HookResult.rejected.index);
    expect(
      lines,
      contains(
        allOf(
          startsWith('  [ERR] '),
          endsWith('Source file is not exported anywhere'),
        ),
      ),
    );
  });
}
