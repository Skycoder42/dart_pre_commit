import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_test_tools/test.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

void main() {
  group('LogLevel', () {
    testData<Tuple2<LogLevel, String>>(
      'correctly generates and parses name',
      const [
        Tuple2(LogLevel.debug, 'debug'),
        Tuple2(LogLevel.info, 'info'),
        Tuple2(LogLevel.warn, 'warn'),
        Tuple2(LogLevel.error, 'error'),
        Tuple2(LogLevel.except, 'except'),
        Tuple2(LogLevel.nothing, 'nothing'),
      ],
      (fixture) {
        expect(fixture.item1.name, fixture.item2);
        expect(LogLevel.values.byName(fixture.item2), fixture.item1);
      },
    );

    test('throws if parse is called with invalid data', () {
      expect(
        () => LogLevel.values.byName('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
