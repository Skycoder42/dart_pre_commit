import 'dart:io';

import 'logger.dart';
import 'task_error.dart';

class Format {
  final Logger logger;

  const Format(this.logger);

  Future<bool> call(File file) async {
    final process = await Process.start(
      Platform.isWindows ? "dartfmt.bat" : "dartfmt",
      [
        "--overwrite",
        "--fix",
        "--set-exit-if-changed",
        file.path,
      ],
    );
    logger.pipeStderr(process.stderr);
    process.stdout.drain<void>();
    final exitCode = await process.exitCode;
    switch (exitCode) {
      case 0:
        return false;
      case 1:
        return true;
      default:
        throw TaskError("dartfmt failed to format the file", file);
    }
  }
}
