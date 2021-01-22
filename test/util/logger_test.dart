import 'package:dart_pre_commit/src/util/logger.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart'; // ignore: import_of_legacy_library_into_null_safe

import '../test_with_data.dart';

void main() {
  group('LogLevel', () {
    testWithData<Tuple2<LogLevel, String>>(
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
        expect(LogLevelX.parse(fixture.item2), fixture.item1);
      },
    );
  });
}
