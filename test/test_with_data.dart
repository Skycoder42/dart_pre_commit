import 'package:meta/meta.dart';
import 'package:test/test.dart';

@isTestGroup
void testWithData<TFixture>(
  dynamic description,
  List<TFixture> fixtures,
  dynamic Function(TFixture fixture) body, {
  String testOn,
  Timeout timeout,
  dynamic skip,
  dynamic tags,
  Map<String, dynamic> onPlatform,
  int retry,
  String Function(TFixture fixture) fixtureToString,
}) {
  assert(fixtures.isNotEmpty);
  group(description, () {
    for (final fixture in fixtures) {
      test(
        fixtureToString != null ? fixtureToString(fixture) : fixture.toString(),
        () => body(fixture),
        testOn: testOn,
        timeout: timeout,
        skip: skip,
        tags: tags,
        onPlatform: onPlatform,
        retry: retry,
      );
    }
  });
}
