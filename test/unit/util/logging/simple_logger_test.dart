// ignore_for_file: unnecessary_lambdas

import 'dart:io';

import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/logging/simple_logger.dart';
import 'package:dart_test_tools/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockIOSink extends Mock implements IOSink {}

void main() {
  final mockOutSink = MockIOSink();
  final mockErrSink = MockIOSink();

  late SimpleLogger sut;

  setUp(() {
    reset(mockOutSink);
    reset(mockErrSink);

    sut = SimpleLogger(
      outSink: mockOutSink,
      errSink: mockErrSink,
      LogLevel.debug,
    );
  });

  test('uses stdout and stderr by default', () {
    sut = SimpleLogger(LogLevel.debug);

    expect(sut.outSink, same(stdout));
    expect(sut.errSink, same(stderr));
  });

  group('updateStatus', () {
    test('prints message', () {
      sut.updateStatus(message: 'message');
      verifyInOrder([
        () => mockOutSink.write('message'),
        () => mockOutSink.writeln(),
      ]);
      verifyNoMoreInteractions(mockOutSink);
    });

    testData<(TaskStatus, String)>(
      'prints status',
      const [
        (TaskStatus.scanning, '[S] '),
        (TaskStatus.clean, '[C] '),
        (TaskStatus.hasChanges, '[M] '),
        (TaskStatus.hasUnstagedChanges, '[U] '),
        (TaskStatus.rejected, '[R] '),
      ],
      (fixture) {
        sut.updateStatus(status: fixture.$1);
        verifyInOrder([
          () => mockOutSink.write(fixture.$2),
          () => mockOutSink.write(''),
          () => mockOutSink.writeln(),
        ]);
        verifyNoMoreInteractions(mockOutSink);
      },
    );

    test('prints detail', () {
      sut.updateStatus(detail: 'detail');
      verifyInOrder([
        () => mockOutSink.write(''),
        () => mockOutSink.write(' detail'),
        () => mockOutSink.writeln(),
      ]);
      verifyNoMoreInteractions(mockOutSink);
    });

    test('refresh caches update but does not print yet', () {
      sut.updateStatus(message: 'test', refresh: false);
      verifyZeroInteractions(mockOutSink);

      sut.updateStatus(detail: 'detail');
      verifyInOrder([
        () => mockOutSink.write('test'),
        () => mockOutSink.write(' detail'),
        () => mockOutSink.writeln(),
      ]);
      verifyNoMoreInteractions(mockOutSink);
    });

    testData<(String?, TaskStatus?, String?, bool, Iterable<String>)>(
      'update and clear use old state correctly',
      const [
        ('msg', null, null, false, ['[S] ', 'msg', ' test2']),
        (null, TaskStatus.clean, null, false, ['[C] ', 'test1', ' test2']),
        (null, null, 'dtl', false, ['[S] ', 'test1', ' dtl']),
        ('msg', TaskStatus.clean, null, false, ['[C] ', 'msg', ' test2']),
        ('msg', null, 'dtl', false, ['[S] ', 'msg', ' dtl']),
        (null, TaskStatus.clean, 'dtl', false, ['[C] ', 'test1', ' dtl']),
        ('msg', TaskStatus.clean, 'dtl', false, ['[C] ', 'msg', ' dtl']),
        ('msg', null, null, true, ['msg']),
        (null, TaskStatus.clean, null, true, ['[C] ', '']),
        (null, null, 'dtl', true, ['', ' dtl']),
        ('msg', TaskStatus.clean, null, true, ['[C] ', 'msg']),
        ('msg', null, 'dtl', true, ['msg', ' dtl']),
        (null, TaskStatus.clean, 'dtl', true, ['[C] ', '', ' dtl']),
        ('msg', TaskStatus.clean, 'dtl', true, ['[C] ', 'msg', ' dtl']),
      ],
      (fixture) {
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
        verifyInOrder([
          () => mockOutSink.write('[S] '),
          () => mockOutSink.write('test1'),
          () => mockOutSink.write(' test2'),
          () => mockOutSink.writeln(),
          ...fixture.$5.map(
            (e) =>
                () => mockOutSink.write(e),
          ),
          () => mockOutSink.writeln(),
        ]);
        verifyNoMoreInteractions(mockOutSink);
      },
    );
  });

  test('completeStatus does nothing', () {
    sut.completeStatus();
    verifyZeroInteractions(mockOutSink);
  });

  group('task logging', () {
    testData<(void Function(SimpleLogger), String)>(
      'prints log',
      [
        ((l) => l.debug('debug'), '  [DBG] debug'),
        ((l) => l.info('info'), '  [INF] info'),
        ((l) => l.warn('warn'), '  [WRN] warn'),
        ((l) => l.error('error'), '  [ERR] error'),
        ((l) => l.except(Exception('error')), '  [EXC] Exception: error'),
        (
          (l) => l.except(Exception('error'), StackTrace.empty),
          '  [EXC] Exception: error\n',
        ),
      ],
      (fixture) {
        fixture.$1(sut);
        verify(() => mockOutSink.writeln(fixture.$2));
        verifyNoMoreInteractions(mockOutSink);
      },
    );

    testData<
      (LogLevel, void Function(SimpleLogger)?, void Function(SimpleLogger)?)
    >(
      'honors logLevel',
      [
        (LogLevel.debug, null, (l) => l.debug('')),
        (LogLevel.info, (l) => l.debug(''), (l) => l.info('')),
        (LogLevel.warn, (l) => l.info(''), (l) => l.warn('')),
        (LogLevel.error, (l) => l.warn(''), (l) => l.error('')),
        (LogLevel.except, (l) => l.error(''), (l) => l.except(Exception())),
        (LogLevel.nothing, (l) => l.except(Exception()), null),
      ],
      (fixture) {
        sut = SimpleLogger(
          outSink: mockOutSink,
          errSink: mockErrSink,
          fixture.$1,
        );

        fixture.$2?.call(sut);
        verifyZeroInteractions(mockOutSink);

        if (fixture.$3 != null) {
          fixture.$3!(sut);
          verify(() => mockOutSink.writeln(any())).called(1);
          verifyNoMoreInteractions(mockOutSink);
        }
      },
    );
  });

  test('pipeStderr pipes errors to sink', () async {
    final errStream = Stream.fromIterable([
      [1, 2, 3],
      [4, 5],
    ]);

    await sut.pipeStderr(errStream);

    verifyInOrder([
      () => mockErrSink.add([1, 2, 3]),
      () => mockErrSink.add([4, 5]),
    ]);
    verifyNoMoreInteractions(mockErrSink);
  });
}
