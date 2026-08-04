import '../features/native_push/native_push_verification.dart';
import '../router/app_router.dart';

/// Verifies notification target route matches opened route; records evidence.
class PushDeepLinkHandler {
  PushDeepLinkHandler(this._store);

  final NativePushVerificationStore _store;

  static const archiveRoute = '/archive-belief';
  static const recordRoute = '/record';

  String? _lastExpectedRoute;
  String? _lastActualRoute;

  String? get lastExpectedRoute => _lastExpectedRoute;
  String? get lastActualRoute => _lastActualRoute;

  Future<void> handleMessageOpen({
    required String platform,
    required Map<String, dynamic> data,
  }) async {
    final expected = (data['expectedRoute'] ?? data['route'])?.toString();
    if (expected == null || expected.isEmpty) return;

    _lastExpectedRoute = expected;
    await _store.patchPlatform(platform, notificationOpened: true);

    appRouter.go(expected);
    final actual = appRouter.state.uri.path;
    _lastActualRoute = actual;

    if (expected == actual) {
      await _store.verifyDestination(platform: platform, route: expected);
    }
  }

  Future<void> recordReceived(String platform) async {
    await _store.patchPlatform(platform, notificationReceived: true);
  }
}
