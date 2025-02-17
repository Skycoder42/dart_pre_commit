// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_test_tools/tools.dart';

Future<void> main(List<String> args) async {
  final client = HttpClient();
  try {
    final channel = args.isNotEmpty ? args[0] : 'stable';
    final toolDir = Directory(args.length >= 2 ? args[1] : 'tool');

    // find the latest version of the flutter tool
    final osName = Github.env.runnerOs!.toLowerCase();
    print('::debug::Checking for latest version of $channel for $osName');
    final manifestRequest = await client.getUrl(
      Uri.https(
        'storage.googleapis.com',
        '/flutter_infra_release/releases/releases_$osName.json',
      ),
    );
    final manifestResponse = await manifestRequest.close();
    final manifest =
        await manifestResponse
            .transform(utf8.decoder)
            .transform(json.decoder)
            .cast<Map<String, dynamic>>()
            .single;
    final releaseVersion = _getLatestVersion(channel, manifest);
    final release = _getRelease(channel, releaseVersion, manifest);

    // download and extract the flutter tool
    print('::debug::Downloading ${release.archive}...');
    final archive = await client.download(
      Github.env.runnerTemp,
      release.archive,
      withSignature: false,
    );
    print('::debug::Verifying sha256 sum of ${archive.path}...');
    final hash = await archive.openRead().transform(sha256).single;
    if (hash != release.sha256) {
      throw Exception('Hash mismatch for $archive!');
    }
    print('::debug::Extracting ${archive.path} to $toolDir...');
    await Archive.extract(archive: archive, outDir: toolDir);

    final flutterBin = toolDir
        .subDir('flutter')
        .subDir('bin')
        .subFile('flutter${Platform.isWindows ? '.bat' : ''}');
    if (!flutterBin.existsSync()) {
      throw Exception('Flutter binary ${flutterBin.path} does not exist');
    }

    await Github.exec(await flutterBin.resolveSymbolicLinks(), const [
      'doctor',
      '-v',
    ]);

    await Github.env.addPath(flutterBin.parent);
  } finally {
    client.close();
  }
}

String _getLatestVersion(String channel, Map<String, dynamic> manifest) {
  final currentRelease = manifest['current_release'] as Map<String, dynamic>;
  return currentRelease[channel] as String;
}

({String version, Uri archive, Digest sha256}) _getRelease(
  String channel,
  String version,
  Map<String, dynamic> manifest,
) {
  final arch = Github.env.runnerArch!.toLowerCase();
  final releases =
      (manifest['releases'] as List<dynamic>).cast<Map<String, dynamic>>();
  final release =
      releases
          .where((r) => r['channel'] == channel)
          .where((r) => r['hash'] == version)
          .where((r) => r['dart_sdk_arch'] == arch)
          .single;
  final baseUrl = Uri.parse('${manifest['base_url']}/');
  return (
    version: release['version'] as String,
    archive: baseUrl.resolve(release['archive'] as String),
    sha256: _parseDigest(release['sha256'] as String),
  );
}

Digest _parseDigest(String hexString) {
  final bytes = Uint8List(hexString.length ~/ 2);
  for (var i = 0; i < hexString.length; i += 2) {
    bytes[i ~/ 2] = int.parse(hexString.substring(i, i + 2), radix: 16);
  }
  return Digest(bytes);
}
