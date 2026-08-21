/// Ensures reflection embedding work never overlaps with outbound HTTP.
abstract final class OfflineReflectionSearchGuard {
  OfflineReflectionSearchGuard._();

  static var _inFlight = 0;

  static bool get isEmbeddingInFlight => _inFlight > 0;

  static Future<T> runOffline<T>(Future<T> Function() action) async {
    _inFlight++;
    try {
      return await action();
    } finally {
      _inFlight--;
    }
  }
}
