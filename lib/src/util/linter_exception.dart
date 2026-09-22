import 'package:meta/meta.dart';

/// @nodoc
@internal
class LinterException(
  /// @nodoc
  final String message,
) implements Exception {
  /// @nodoc
  this;

  // coverage:ignore-start
  @override
  String toString() => message;
  // coverage:ignore-end
}
