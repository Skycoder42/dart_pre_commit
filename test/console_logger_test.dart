import 'dart:convert';

import 'package:console/console.dart'; // ignore: import_of_legacy_library_into_null_safe
import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:dart_pre_commit/src/console_logger.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart'; // ignore: import_of_legacy_library_into_null_safe

import 'test_with_data.dart';

const eraseLine = '\x1B[0K';
const newLine = '\x1B[1E';
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

    sut = ConsoleLogger();
  });

  group('updateStatus', () {
    test('prints message', () {
      sut.updateStatus(message: 'test');
      expect(output.toString(), cleanLine('test'));
    });

    testWithData<Tuple2<TaskStatus, String>>('prints status', const [
      Tuple2(TaskStatus.scanning, '🔎 '),
      Tuple2(TaskStatus.clean, '✔ '),
      Tuple2(TaskStatus.hasChanges, '🖉 '),
      Tuple2(TaskStatus.hasUnstagedChanges, '⚠ '),
      Tuple2(TaskStatus.rejected, '❌ '),
    ], (fixture) {
      sut.updateStatus(message: 'test');
      expect(output.toString(), cleanLine('test'));
    });

    test('prints detail', () {
      sut.updateStatus(detail: 'test');
      expect(output.toString(), cleanLine(italic(' test')));
    });

    testWithData<Tuple5<String?, TaskStatus?, String?, bool, String>>(
        'update and clear use old state correctly', [
      Tuple5('msg', null, null, false, '🔎 msg${italic(' test2')}'),
      Tuple5(null, TaskStatus.clean, null, false, '✔ test1${italic(' test2')}'),
      Tuple5(null, null, 'dtl', false, '🔎 test1${italic(' dtl')}'),
      Tuple5('msg', TaskStatus.clean, null, false, '✔ msg${italic(' test2')}'),
      Tuple5('msg', null, 'dtl', false, '🔎 msg${italic(' dtl')}'),
      Tuple5(null, TaskStatus.clean, 'dtl', false, '✔ test1${italic(' dtl')}'),
      Tuple5('msg', TaskStatus.clean, 'dtl', false, '✔ msg${italic(' dtl')}'),
      const Tuple5('msg', null, null, true, 'msg'),
      const Tuple5(null, TaskStatus.clean, null, true, '✔ '),
      Tuple5(null, null, 'dtl', true, italic(' dtl')),
      const Tuple5('msg', TaskStatus.clean, null, true, '✔ msg'),
      Tuple5('msg', null, 'dtl', true, 'msg${italic(' dtl')}'),
      Tuple5(null, TaskStatus.clean, 'dtl', true, '✔ ${italic(' dtl')}'),
      Tuple5(
        'msg',
        TaskStatus.clean,
        'dtl',
        true,
        '✔ msg${italic(' dtl')}',
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
    testWithData<Tuple3<void Function(ConsoleLogger), int, String>>(
      'prints log message',
      [
        Tuple3((l) => l.debug('debug'), 37, 'debug'),
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
          startsWith(cleanLine(
            '${beginColor(fixture.item2)}  ${fixture.item3}$endColor$newLine',
          )),
        );
      },
    );

    test('reprints status after any log', () {
      sut
        ..updateStatus(message: 'status')
        ..debug('debug');
      expect(
        output.toString(),
        cleanLine('status') +
            cleanLine('${beginColor(37)}  debug$endColor$newLine') +
            cleanLine('status'),
      );
    });
  });

  test('pipeStderr prints error lines', () async {
    final errStream = Stream.fromIterable(['msg1']).transform(utf8.encoder);

    await sut.pipeStderr(errStream);

    expect(
      output.toString(),
      startsWith(
        cleanLine('${beginColor(31)}  msg1$endColor$newLine'),
      ),
    );
  });
}
