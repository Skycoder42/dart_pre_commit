import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:dart_test_tools/test.dart';
import 'package:test/test.dart';

void main() {
  group('LogLevel', () {
    testData<(LogLevel, String)>(
      'correctly generates and parses name',
      const [
        (LogLevel.debug, 'debug'),
        (LogLevel.info, 'info'),
        (LogLevel.warn, 'warn'),
        (LogLevel.error, 'error'),
        (LogLevel.except, 'except'),
        (LogLevel.nothing, 'nothing'),
      ],
      (fixture) {
        expect(fixture.$1.name, fixture.$2);
        expect(LogLevel.values.byName(fixture.$2), fixture.$1);
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
