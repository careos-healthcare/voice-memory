import 'dart:async';

import 'package:archiveme_mobile/features/live_audio/infrastructure/network_connectivity_source.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Network connectivity source combining OS link status with lifecycle resume.
class ConnectivityAwareNetworkSource implements NetworkConnectivitySource {
  ConnectivityAwareNetworkSource({
    Connectivity? connectivity,
    LifecycleNetworkConnectivitySource? lifecycle,
  }) : _connectivity = connectivity ?? Connectivity(),
       _lifecycle = lifecycle ?? LifecycleNetworkConnectivitySource();

  final Connectivity _connectivity;
  final LifecycleNetworkConnectivitySource _lifecycle;
  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  var _isOnline = true;
  var _started = false;

  @override
  Stream<void> get onConnectivityRestored => _lifecycle.onConnectivityRestored;

  @override
  Stream<bool> get onOnlineChanged => _onlineController.stream;

  @override
  bool get isOnline => _isOnline;

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_refreshOnline(notifyRestore: false));
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (_) => unawaited(_refreshOnline(notifyRestore: true)),
    );
  }

  void notifyConnectivityRestored() {
    _lifecycle.notifyConnectivityRestored();
    unawaited(_refreshOnline(notifyRestore: true));
  }

  Future<void> _refreshOnline({required bool notifyRestore}) async {
    final results = await _connectivity.checkConnectivity();
    final online = _hasUsableConnectivity(results);
    if (online == _isOnline) {
      if (online && notifyRestore) {
        _lifecycle.notifyConnectivityRestored();
      }
      return;
    }

    _isOnline = online;
    if (!_onlineController.isClosed) {
      _onlineController.add(online);
    }
    if (online && notifyRestore) {
      _lifecycle.notifyConnectivityRestored();
    }
  }

  bool _hasUsableConnectivity(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      return false;
    }
    return results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn ||
          result == ConnectivityResult.other,
    );
  }

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
    _lifecycle.dispose();
    unawaited(_onlineController.close());
  }
}
