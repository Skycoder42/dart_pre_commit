// ignore_for_file: avoid_print
import 'dart:io';

import 'package:test/test.dart';

void main() {
  final cwd = Directory.current;

  setUp(() async {
    // create git repo
    Directory.current = await Directory.systemTemp.createTemp();
    await _git(const ["init"]);

    // create files
    await File("pubspec.yaml").writeAsString("""
name: test_project
version: 0.0.1

environment:
  sdk: ">=2.7.0 <3.0.0"

dependencies:
  meta: null

dev_dependencies:
  lint: null
""");

    // init dart
    await _pub(const ["get"]);
  });

  tearDown(() async {
    final tDir = Directory.current;
    Directory.current = cwd;
    await tDir.delete(recursive: true);
  });

  test('does nothing if all is ok', () {});
}

Future<void> _run(String program, List<String> arguments) async {
  print("\$ $program ${arguments.join(" ")}");
  final proc = await Process.start(program, arguments);
  proc.stdout.listen(stdout.add);
  proc.stderr.listen(stderr.add);
  final exitCode = await proc.exitCode;
  if (exitCode != 0) {
    throw "Failed to run '$program ${arguments.join(" ")}' with exit code: $exitCode";
  }
}

Future<void> _git(List<String> arguments) async => _run("git", arguments);

Future<void> _pub(List<String> arguments) async =>
    _run(Platform.isWindows ? "pub.bat" : "pub", arguments);
