import 'dart:async';

/// Emits when the device likely has usable network again (app resume / reconnect).
abstract class NetworkConnectivitySource {
  Stream<void> get onConnectivityRestored;

  void dispose();
}

/// Foreground/resume hook — call [notifyConnectivityRestored] when app resumes.
class LifecycleNetworkConnectivitySource implements NetworkConnectivitySource {
  LifecycleNetworkConnectivitySource();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get onConnectivityRestored => _controller.stream;

  void notifyConnectivityRestored() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  @override
  void dispose() {
    _controller.close();
  }
}
