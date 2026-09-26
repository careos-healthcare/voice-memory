import 'dart:developer' as developer;

/// Unified logging for Thoughtprint — wraps [developer.log] for debug output.
abstract final class AppLogger {
  AppLogger._();

  static void debug(
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name ?? 'Thoughtprint',
      level: 500,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name ?? 'Thoughtprint',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
