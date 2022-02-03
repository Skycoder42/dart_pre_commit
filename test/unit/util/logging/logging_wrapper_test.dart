import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_pre_commit/src/util/logging/logging_wrapper.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../../test_with_data.dart';

class MockTaskLogger extends Mock implements TaskLogger {}

void main() {
  setUpAll(() {
    registerFallbackValue(Exception());
  });

  group('LoggingWrapper', () {
    final mockTaskLogger = MockTaskLogger();

    late LoggingWrapper sut;

    setUp(() {
      reset(mockTaskLogger);

      sut = LoggingWrapper(mockTaskLogger);
    });

    test('get level returns Level.ALL', () {
      expect(sut.level, Level.ALL);
    });

    test('set level does nothing', () {
      sut.level = Level.OFF;
      expect(sut.level, Level.ALL);
    });

    test('children returns an empty map', () {
      expect(sut.children, isEmpty);
    });

    testWithData<Tuple2<String, void Function(String)>>(
      'logs debug messages',
      [
        Tuple2('CONFIG', (m) => sut.config(m)),
        Tuple2('FINE', (m) => sut.fine(m)),
        Tuple2('FINER', (m) => sut.finer(m)),
        Tuple2('FINEST', (m) => sut.finest(m)),
      ],
      (fixture) {
        fixture.item2(fixture.item1);
        verify(() => mockTaskLogger.debug(fixture.item1));
      },
    );

    test('fullName should be empty', () {
      expect(sut.fullName, isEmpty);
    });

    test('info should log an info message', () {
      sut.info('INFO');
      verify(() => mockTaskLogger.info('INFO'));
    });

    testWithData<Level>(
      'isLoggable should always return true',
      Level.LEVELS,
      (level) {
        expect(sut.isLoggable(level), isTrue);
      },
    );

    testWithData<Tuple2<Level, void Function(String)>>(
      'log should log according to level',
      [
        Tuple2(Level.ALL, mockTaskLogger.debug),
        Tuple2(Level.FINEST, mockTaskLogger.debug),
        Tuple2(Level.FINER, mockTaskLogger.debug),
        Tuple2(Level.FINE, mockTaskLogger.debug),
        Tuple2(Level.CONFIG, mockTaskLogger.debug),
        Tuple2(Level.INFO, mockTaskLogger.info),
        Tuple2(Level.WARNING, mockTaskLogger.warn),
        Tuple2(Level.SEVERE, mockTaskLogger.error),
        Tuple2(
          Level.SHOUT,
          (m) => mockTaskLogger.except(
            any(
              that: isA<LoggingWrapperException>()
                  .having((e) => e.message, 'message', m),
            ),
            any(that: isNull),
          ),
        ),
      ],
      (fixture) {
        const message = 'test-message';
        sut.log(fixture.item1, message);
        verify(() => fixture.item2(message));
      },
    );

    test('name should be empty', () {
      expect(sut.name, isEmpty);
    });

    test('onRecord should return an empty stream', () {
      expect(sut.onRecord, emitsDone);
    });

    test('parent should be null', () {
      expect(sut.parent, isNull);
    });

    test('severe should log an error message', () {
      sut.severe('SEVERE');
      verify(() => mockTaskLogger.error('SEVERE'));
    });

    test('shout should log an exception', () {
      final error = Exception();
      final stackTrace = StackTrace.current;
      sut.shout('error', error, stackTrace);
      verify(() => mockTaskLogger.except(error, stackTrace));
    });

    test('shout should log an except message', () {
      sut.shout('SHOUT');
      verify(
        () => mockTaskLogger.except(
          any(
            that: isA<LoggingWrapperException>()
                .having((e) => e.message, 'message', 'SHOUT'),
          ),
          any(that: isNull),
        ),
      );
    });

    test('warning should log a warn message', () {
      sut.warning('WARNING');
      verify(() => mockTaskLogger.warn('WARNING'));
    });
  });
}
