// ignore_for_file: avoid_print

import 'dart:io';

class ExitCodeException implements Exception {
  final String program;
  final int exitCode;

  ExitCodeException(this.program, this.exitCode);

  @override
  String toString() => '::error::$program failed with exit code: $exitCode';
}

Future<void> main(List<String> args) async {
  try {
    final branch = args.isNotEmpty ? args[0] : 'stable';
    final toolPath = args.length >= 2 ? args[1] : 'tool/.flutter';

    await _exec('git', [
      'clone',
      'https://github.com/flutter/flutter.git',
      '--depth',
      '1',
      '-b',
      branch,
      toolPath,
    ]);
    final flutterBin = File(
      '$toolPath/bin/flutter${Platform.isWindows ? '.bat' : ''}',
    );
    if (!flutterBin.existsSync()) {
      throw Exception('Flutter binary ${flutterBin.path} does not exist');
    }

    await _exec(await flutterBin.resolveSymbolicLinks(), const [
      'doctor',
      '-v',
    ]);

    await _addToPath(Platform.executable);
    await _addToPath(await flutterBin.parent.resolveSymbolicLinks());
    await _addToPath(Platform.executable);
  } on ExitCodeException catch (e) {
    print(e);
    exitCode = e.exitCode;
  }
}

Future<void> _exec(String program, List<String> args) async {
  print("::debug::Running $program ${args.join(' ')}");
  final proc = await Process.start(
    program,
    args,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await proc.exitCode;
  if (exitCode != 0) {
    throw ExitCodeException(program, exitCode);
  }
}

Future<void> _addToPath(String path) async {
  print('::debug::Adding path: $path');
  final githubPathFile = File(Platform.environment['GITHUB_PATH']!);
  await githubPathFile.writeAsString(
    '$path\n',
    mode: FileMode.append,
    flush: true,
    encoding: systemEncoding,
  );
}
