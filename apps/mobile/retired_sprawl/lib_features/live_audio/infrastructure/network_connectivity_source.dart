import 'dart:async';

/// Emits when the device likely has usable network again (app resume / reconnect).
abstract class NetworkConnectivitySource {
  Stream<void> get onConnectivityRestored;

  /// Emits `true` when online and `false` when offline.
  Stream<bool> get onOnlineChanged;

  /// Latest known online status.
  bool get isOnline;

  void dispose();
}

/// Foreground/resume hook — call [notifyConnectivityRestored] when app resumes.
class LifecycleNetworkConnectivitySource implements NetworkConnectivitySource {
  LifecycleNetworkConnectivitySource();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get onConnectivityRestored => _controller.stream;

  @override
  Stream<bool> get onOnlineChanged => const Stream.empty();

  @override
  bool get isOnline => true;

  void notifyConnectivityRestored() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}