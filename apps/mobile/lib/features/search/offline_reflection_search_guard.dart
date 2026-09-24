import 'package:archiveme_mobile/core/execution/isolate_compute_job.dart';

/// Ensures reflection embedding work never overlaps with outbound HTTP.
abstract final class OfflineReflectionSearchGuard {
  OfflineReflectionSearchGuard._();

  static var _inFlight = 0;

  /// Caps concurrent embed+search pairs so device RAM is not flooded.
  static final IsolateJobThrottle searchThrottle = IsolateJobThrottle(
    maxConcurrent: 2,
  );

  static bool get isEmbeddingInFlight => _inFlight > 0;

  static Future<T> runOffline<T>(Future<T> Function() action) {
    return searchThrottle.run(() async {
      _inFlight++;
      try {
        return await action();
      } finally {
        _inFlight--;
      }
    });
  }
}
