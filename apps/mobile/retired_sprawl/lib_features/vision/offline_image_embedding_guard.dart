/// Enforces zero-network execution for on-device image embedding.
abstract final class OfflineImageEmbeddingGuard {
  OfflineImageEmbeddingGuard._();

  static var _depth = 0;

  /// True while [runOffline] is executing image embedding work.
  static bool get isActive => _depth > 0;

  /// Runs [operation] under offline enforcement. Network clients may call
  /// [assertOfflineBlocked] to fail closed when image bytes are in-flight.
  static Future<T> runOffline<T>(Future<T> Function() operation) async {
    _depth++;
    try {
      return await operation();
    } finally {
      _depth--;
    }
  }

  /// Throws when a network call is attempted during offline image embedding.
  static void assertOfflineBlocked({required String operation}) {
    if (!isActive) return;
    throw OfflineImageEmbeddingViolation(
      'Network blocked during offline image embedding: $operation',
    );
  }
}

/// Raised when image embedding work would leave the device.
class OfflineImageEmbeddingViolation implements Exception {
  OfflineImageEmbeddingViolation(this.message);

  final String message;

  @override
  String toString() => message;
}
