import 'dart:io';

import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/logging/simple_logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../../test_with_data.dart';
import 'simple_logger_test.mocks.dart';

@GenerateMocks([], customMocks: [
  MockSpec<IOSink>(returnNullOnMissingStub: true),
])
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
      logLevel: LogLevel.debug,
    );
  });

  group('updateStatus', () {
    test('prints message', () {
      sut.updateStatus(message: 'message');
      verifyInOrder([
        mockOutSink.write('message'),
        mockOutSink.writeln(),
      ]);
      verifyNoMoreInteractions(mockOutSink);
    });

    testWithData<Tuple2<TaskStatus, String>>('prints status', const [
      Tuple2(TaskStatus.scanning, '[S] '),
      Tuple2(TaskStatus.clean, '[C] '),
      Tuple2(TaskStatus.hasChanges, '[M] '),
      Tuple2(TaskStatus.hasUnstagedChanges, '[U] '),
      Tuple2(TaskStatus.rejected, '[R] '),
    ], (fixture) {
      sut.updateStatus(status: fixture.item1);
      verifyInOrder([
        mockOutSink.write(fixture.item2),
        mockOutSink.write(''),
        mockOutSink.writeln(),
      ]);
      verifyNoMoreInteractions(mockOutSink);
    });

    test('prints detail', () {
      sut.updateStatus(detail: 'detail');
      verifyInOrder([
        mockOutSink.write(''),
        mockOutSink.write(' detail'),
        mockOutSink.writeln(),
      ]);
      verifyNoMoreInteractions(mockOutSink);
    });

    test('refresh caches update but does not print yet', () {
      sut.updateStatus(message: 'test', refresh: false);
      verifyZeroInteractions(mockOutSink);

      sut.updateStatus(detail: 'detail');
      verifyInOrder([
        mockOutSink.write('test'),
        mockOutSink.write(' detail'),
        mockOutSink.writeln(),
      ]);
      verifyNoMoreInteractions(mockOutSink);
    });

    testWithData<Tuple5<String?, TaskStatus?, String?, bool, Iterable<String>>>(
      'update and clear use old state correctly',
      const [
        Tuple5('msg', null, null, false, ['[S] ', 'msg', ' test2']),
        Tuple5(
          null,
          TaskStatus.clean,
          null,
          false,
          ['[C] ', 'test1', ' test2'],
        ),
        Tuple5(null, null, 'dtl', false, ['[S] ', 'test1', ' dtl']),
        Tuple5('msg', TaskStatus.clean, null, false, ['[C] ', 'msg', ' test2']),
        Tuple5('msg', null, 'dtl', false, ['[S] ', 'msg', ' dtl']),
        Tuple5(null, TaskStatus.clean, 'dtl', false, ['[C] ', 'test1', ' dtl']),
        Tuple5('msg', TaskStatus.clean, 'dtl', false, ['[C] ', 'msg', ' dtl']),
        Tuple5('msg', null, null, true, ['msg']),
        Tuple5(null, TaskStatus.clean, null, true, ['[C] ', '']),
        Tuple5(null, null, 'dtl', true, ['', ' dtl']),
        Tuple5('msg', TaskStatus.clean, null, true, ['[C] ', 'msg']),
        Tuple5('msg', null, 'dtl', true, ['msg', ' dtl']),
        Tuple5(null, TaskStatus.clean, 'dtl', true, ['[C] ', '', ' dtl']),
        Tuple5('msg', TaskStatus.clean, 'dtl', true, ['[C] ', 'msg', ' dtl']),
      ],
      (fixture) {
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
        verifyInOrder([
          mockOutSink.write('[S] '),
          mockOutSink.write('test1'),
          mockOutSink.write(' test2'),
          mockOutSink.writeln(),
          ...fixture.item5.map((e) => mockOutSink.write(e)),
          mockOutSink.writeln(),
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
    testWithData<Tuple2<void Function(SimpleLogger), String>>(
      'prints log',
      [
        Tuple2((l) => l.debug('debug'), '  [DBG] debug'),
        Tuple2((l) => l.info('info'), '  [INF] info'),
        Tuple2((l) => l.warn('warn'), '  [WRN] warn'),
        Tuple2((l) => l.error('error'), '  [ERR] error'),
        Tuple2((l) => l.except(Exception('error')), '  [EXC] Exception: error'),
        Tuple2(
          (l) => l.except(Exception('error'), StackTrace.empty),
          '  [EXC] Exception: error\n',
        ),
      ],
      (fixture) {
        fixture.item1(sut);
        verify(mockOutSink.writeln(fixture.item2));
        verifyNoMoreInteractions(mockOutSink);
      },
    );

    testWithData<
        Tuple3<LogLevel, void Function(SimpleLogger)?,
            void Function(SimpleLogger)?>>(
      'honors logevel',
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
        sut.logLevel = fixture.item1;

        fixture.item2?.call(sut);
        verifyZeroInteractions(mockOutSink);

        if (fixture.item3 != null) {
          fixture.item3!(sut);
          verify(mockOutSink.writeln(any)).called(1);
          verifyNoMoreInteractions(mockOutSink);
        }
      },
    );
  });

  test('pipeStderr pipes errors to sink', () async {
    final errStream = Stream.fromIterable([
      [1, 2, 3],
      [4, 5]
    ]);

    await sut.pipeStderr(errStream);

    verifyInOrder([
      mockErrSink.add([1, 2, 3]),
      mockErrSink.add([4, 5]),
    ]);
    verifyNoMoreInteractions(mockErrSink);
  });
}
