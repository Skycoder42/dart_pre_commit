// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_pre_commit/src/hooks.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  late Directory testDir;

  Future<void> _writeFile(String path, String contents) async {
    final file = File(join(testDir.path, path));
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(contents);
  }

  Future<String> _readFile(String path) =>
      File(join(testDir.path, path)).readAsString();

  Future<int> _run(
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

  Future<void> _git(List<String> arguments) async => _run('git', arguments);

  Future<int> _pub(
    List<String> arguments, {
    bool failOnError = true,
    Function(Stream<List<int>>)? onStdout,
  }) =>
      _run(
        'dart',
        [
          'pub',
          ...arguments,
        ],
        failOnError: failOnError,
        onStdout: onStdout,
      );

  Future<int> _sut(
    String mode, {
    List<String>? arguments,
    bool failOnError = true,
    Function(String)? onStdout,
  }) {
    final disableArgs = [
      '--no-format',
      '--no-analyze',
      '--no-test-imports',
      '--no-flutter-compat',
      '--outdated=disabled',
      '--no-check-pull-up',
    ];
    return _pub(
      [
        'run',
        'dart_pre_commit',
        '--no-ansi',
        ...disableArgs.where((arg) => !arg.contains(mode)),
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
    await _git(const ['init']);

    // create files
    await _writeFile(
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

dart_pre_commit:
  allow_outdated:
    - rxdart
''',
    );

    await _writeFile(
      'bin/format.dart',
      '''
import 'package:test_project/test_project.dart';

void main() {
  final x = 'this is a very very very very very very very very very very very very very very very very very very very very very very long string';
}
''',
    );
    await _writeFile(
      'lib/src/analyze.dart',
      '''
void main() {
  var x = 'constant';
}
''',
    );
    await _writeFile('lib/test_project.dart', '');
    await _writeFile(
      'test/test.dart',
      'import "package:test_project/test_project.dart";',
    );

    // init dart
    await _pub(const ['get']);
  });

  tearDown(() async {
    await testDir.delete(recursive: true);
  });

  test('format', () async {
    await _git(const ['add', 'bin/format.dart']);
    await _sut('format');

    final data = await _readFile('bin/format.dart');
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
    await _git(const ['add', 'lib/src/analyze.dart']);

    final lines = <String>[];
    final code = await _sut(
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

  test('flutter-compat', () async {
    printOnFailure('Using PATH: ${Platform.environment['PATH']}');

    await _git(const ['add', 'pubspec.yaml']);

    final lines = <String>[];
    final code = await _sut(
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
  });

  test('check-pull-up', () async {
    await _git(const ['add', 'pubspec.lock']);

    final lines = <String>[];
    final code = await _sut(
      'check-pull-up',
      arguments: const ['--detailed-exit-code'],
      failOnError: false,
      onStdout: lines.add,
    );
    expect(code, HookResult.rejected.index);
    expect(lines, contains(startsWith('  [INF] meta: ^1.2.0 -> 1.')));
  });

  test('outdated', () async {
    final lines = <String>[];
    final code = await _sut(
      'outdated',
      arguments: const ['--detailed-exit-code'],
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
    await _git(const ['add', 'test/test.dart']);
    final code = await _sut(
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
}
