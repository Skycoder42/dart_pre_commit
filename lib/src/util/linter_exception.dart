import 'package:meta/meta.dart';

/// An exception that gets thrown to wrap [FileResult.failure] linter results.
@internal
class LinterException implements Exception {
  /// The `error` message of [FileResult.failure].
  final String message;

  /// Default constructor.
  LinterException(this.message);

  // coverage:ignore-start
  @override
  String toString() => message;
  // coverage:ignore-end
}
