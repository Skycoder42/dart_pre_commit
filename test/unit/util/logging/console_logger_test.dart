import 'dart:convert';

import 'package:console/console.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/logging/console_logger.dart';
import 'package:dart_test_tools/test.dart';
import 'package:test/test.dart';

const eraseLine = '\r\x1B[2K';
const newLine = '\n';
const beginItalic = '\x1B[3m';
const endItalic = '\x1B[23m';
String beginColor(int color) => '\x1B[${color}m';
const endColor = '\x1B[39m';

String cleanLine(String message) => '$eraseLine$message';

String italic(String message) => '$beginItalic$message$endItalic';

void main() {
  final output = BufferConsoleAdapter();

  late ConsoleLogger sut;

  setUpAll(() => Console.adapter = output);

  setUp(() {
    output.clear();

    sut = ConsoleLogger(LogLevel.debug);
  });

  group('updateStatus', () {
    test('prints message', () {
      sut.updateStatus(message: 'test');
      expect(output.toString(), cleanLine('test'));
    });

    testData<(TaskStatus, String)>('prints status', const [
      (TaskStatus.scanning, '🔎 '),
      (TaskStatus.clean, '✅ '),
      (TaskStatus.hasChanges, '✏️ '),
      (TaskStatus.hasUnstagedChanges, '⚠️ '),
      (TaskStatus.rejected, '❌ '),
    ], (fixture) {
      sut.updateStatus(message: 'test', status: fixture.$1);
      expect(output.toString(), contains(fixture.$2));
    });

    test('prints detail', () {
      sut.updateStatus(detail: 'test');
      expect(output.toString(), cleanLine(italic(' test')));
    });

    test('refresh caches update but does not print yet', () {
      sut.updateStatus(message: 'test', refresh: false);
      expect(output.toString(), isEmpty);

      sut.updateStatus(detail: 'test');
      expect(output.toString(), cleanLine('test${italic(' test')}'));
    });

    testData<(String?, TaskStatus?, String?, bool, String)>(
        'update and clear use old state correctly', [
      ('msg', null, null, false, '🔎 msg${italic(' test2')}'),
      (
        null,
        TaskStatus.clean,
        null,
        false,
        '✅ test1${italic(' test2')}',
      ),
      (null, null, 'dtl', false, '🔎 test1${italic(' dtl')}'),
      ('msg', TaskStatus.clean, null, false, '✅ msg${italic(' test2')}'),
      ('msg', null, 'dtl', false, '🔎 msg${italic(' dtl')}'),
      (null, TaskStatus.clean, 'dtl', false, '✅ test1${italic(' dtl')}'),
      ('msg', TaskStatus.clean, 'dtl', false, '✅ msg${italic(' dtl')}'),
      const ('msg', null, null, true, 'msg'),
      const (null, TaskStatus.clean, null, true, '✅ '),
      (null, null, 'dtl', true, italic(' dtl')),
      const ('msg', TaskStatus.clean, null, true, '✅ msg'),
      ('msg', null, 'dtl', true, 'msg${italic(' dtl')}'),
      (null, TaskStatus.clean, 'dtl', true, '✅ ${italic(' dtl')}'),
      (
        'msg',
        TaskStatus.clean,
        'dtl',
        true,
        '✅ msg${italic(' dtl')}',
      ),
    ], (fixture) {
      sut
        ..updateStatus(
          message: 'test1',
          status: TaskStatus.scanning,
          detail: 'test2',
        )
        ..updateStatus(
          message: fixture.$1,
          status: fixture.$2,
          detail: fixture.$3,
          clear: fixture.$4,
        );
      expect(
        output.toString(),
        cleanLine('🔎 test1${italic(' test2')}') + cleanLine(fixture.$5),
      );
    });
  });

  test('completeStatus writes newline', () {
    sut.completeStatus();
    expect(output.toString(), newLine);
  });

  group('task logging', () {
    testData<(void Function(ConsoleLogger), int, String)>(
      'prints log message',
      [
        ((l) => l.debug('debug'), 32, 'debug'),
        ((l) => l.info('info'), 34, 'info'),
        ((l) => l.warn('warn'), 33, 'warn'),
        ((l) => l.error('error'), 31, 'error'),
        ((l) => l.except(Exception('error')), 35, 'Exception: error'),
        (
          (l) => l.except(Exception('error'), StackTrace.empty),
          35,
          'Exception: error\n',
        ),
      ],
      (fixture) {
        fixture.$1(sut);
        expect(
          output.toString(),
          startsWith(
            cleanLine(
              '${beginColor(fixture.$2)}    '
              '${fixture.$3}$endColor$newLine',
            ),
          ),
        );
      },
    );

    test('writes first log to new line and reprints status', () {
      sut.updateStatus(message: 'status');
      output.clear();
      sut.debug('debug');
      expect(
        output.toString(),
        '\n${beginColor(32)}    debug$endColor$newLine${cleanLine('status')}',
      );
    });

    test('writes second log, replacing the status and reprints it', () {
      sut
        ..updateStatus(message: 'status')
        ..debug('debug');
      output.clear();
      sut.info('info');

      expect(
        output.toString(),
        cleanLine('${beginColor(34)}    info$endColor$newLine') +
            cleanLine('status'),
      );
    });

    testData<
        (
          LogLevel,
          void Function(ConsoleLogger)?,
          void Function(ConsoleLogger)?
        )>(
      'honors log level',
      [
        (LogLevel.debug, null, (l) => l.debug('')),
        (LogLevel.info, (l) => l.debug(''), (l) => l.info('')),
        (LogLevel.warn, (l) => l.info(''), (l) => l.warn('')),
        (LogLevel.error, (l) => l.warn(''), (l) => l.error('')),
        (
          LogLevel.except,
          (l) => l.error(''),
          (l) => l.except(Exception()),
        ),
        (LogLevel.nothing, (l) => l.except(Exception()), null),
      ],
      (fixture) {
        sut = ConsoleLogger(fixture.$1);

        fixture.$2?.call(sut);
        expect(output.toString(), isEmpty);

        if (fixture.$3 != null) {
          fixture.$3!(sut);
          expect(output.toString(), isNotEmpty);
        }
      },
    );
  });

  test('pipeStderr prints error lines', () async {
    final errStream = Stream.fromIterable(['msg1']).transform(utf8.encoder);

    await sut.pipeStderr(errStream);

    expect(
      output.toString(),
      startsWith(
        cleanLine('${beginColor(31)}    msg1$endColor$newLine'),
      ),
    );
  });
}
