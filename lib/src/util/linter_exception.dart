import 'package:meta/meta.dart';

/// @nodoc
@internal
class LinterException implements Exception {
  /// @nodoc
  final String message;

  /// @nodoc
  LinterException(this.message);

  // coverage:ignore-start
  @override
  String toString() => message;
  // coverage:ignore-end
}
