import 'dart:convert';

import 'package:console/console.dart';
import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/logging/console_logger.dart';
import 'package:dart_test_tools/test.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

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

    testData<Tuple2<TaskStatus, String>>('prints status', const [
      Tuple2(TaskStatus.scanning, '🔎 '),
      Tuple2(TaskStatus.clean, '✅ '),
      Tuple2(TaskStatus.hasChanges, '✏️ '),
      Tuple2(TaskStatus.hasUnstagedChanges, '⚠️ '),
      Tuple2(TaskStatus.rejected, '❌ '),
    ], (fixture) {
      sut.updateStatus(message: 'test');
      expect(output.toString(), cleanLine('test'));
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

    testData<Tuple5<String?, TaskStatus?, String?, bool, String>>(
        'update and clear use old state correctly', [
      Tuple5('msg', null, null, false, '🔎 msg${italic(' test2')}'),
      Tuple5(
        null,
        TaskStatus.clean,
        null,
        false,
        '✅ test1${italic(' test2')}',
      ),
      Tuple5(null, null, 'dtl', false, '🔎 test1${italic(' dtl')}'),
      Tuple5('msg', TaskStatus.clean, null, false, '✅ msg${italic(' test2')}'),
      Tuple5('msg', null, 'dtl', false, '🔎 msg${italic(' dtl')}'),
      Tuple5(null, TaskStatus.clean, 'dtl', false, '✅ test1${italic(' dtl')}'),
      Tuple5('msg', TaskStatus.clean, 'dtl', false, '✅ msg${italic(' dtl')}'),
      const Tuple5('msg', null, null, true, 'msg'),
      const Tuple5(null, TaskStatus.clean, null, true, '✅ '),
      Tuple5(null, null, 'dtl', true, italic(' dtl')),
      const Tuple5('msg', TaskStatus.clean, null, true, '✅ msg'),
      Tuple5('msg', null, 'dtl', true, 'msg${italic(' dtl')}'),
      Tuple5(null, TaskStatus.clean, 'dtl', true, '✅ ${italic(' dtl')}'),
      Tuple5(
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
          message: fixture.item1,
          status: fixture.item2,
          detail: fixture.item3,
          clear: fixture.item4,
        );
      expect(
        output.toString(),
        cleanLine('🔎 test1${italic(' test2')}') + cleanLine(fixture.item5),
      );
    });
  });

  test('completeStatus writes newline', () {
    sut.completeStatus();
    expect(output.toString(), newLine);
  });

  group('task logging', () {
    testData<Tuple3<void Function(ConsoleLogger), int, String>>(
      'prints log message',
      [
        Tuple3((l) => l.debug('debug'), 32, 'debug'),
        Tuple3((l) => l.info('info'), 34, 'info'),
        Tuple3((l) => l.warn('warn'), 33, 'warn'),
        Tuple3((l) => l.error('error'), 31, 'error'),
        Tuple3((l) => l.except(Exception('error')), 35, 'Exception: error'),
        Tuple3(
          (l) => l.except(Exception('error'), StackTrace.empty),
          35,
          'Exception: error\n',
        ),
      ],
      (fixture) {
        fixture.item1(sut);
        expect(
          output.toString(),
          startsWith(
            cleanLine(
              '${beginColor(fixture.item2)}    '
              '${fixture.item3}$endColor$newLine',
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
        Tuple3<LogLevel, void Function(ConsoleLogger)?,
            void Function(ConsoleLogger)?>>(
      'honors log level',
      [
        Tuple3(LogLevel.debug, null, (l) => l.debug('')),
        Tuple3(LogLevel.info, (l) => l.debug(''), (l) => l.info('')),
        Tuple3(LogLevel.warn, (l) => l.info(''), (l) => l.warn('')),
        Tuple3(LogLevel.error, (l) => l.warn(''), (l) => l.error('')),
        Tuple3(
          LogLevel.except,
          (l) => l.error(''),
          (l) => l.except(Exception()),
        ),
        Tuple3(LogLevel.nothing, (l) => l.except(Exception()), null),
      ],
      (fixture) {
        sut = ConsoleLogger(fixture.item1);

        fixture.item2?.call(sut);
        expect(output.toString(), isEmpty);

        if (fixture.item3 != null) {
          fixture.item3!(sut);
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
