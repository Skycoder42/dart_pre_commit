import 'package:meta/meta.dart';

@internal
class LinterException implements Exception {
  final String message;

  LinterException(this.message);

  // coverage:ignore-start
  @override
  String toString() => message;
  // coverage:ignore-end
}
