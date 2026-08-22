import 'dart:async';

import 'package:archiveme_mobile/features/live_audio/infrastructure/network_connectivity_source.dart';
import 'package:archiveme_mobile/features/sync/application/background_sync_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod surface for live device connectivity used by sync status UI.
class NetworkConnectivityNotifier extends Notifier<bool> {
  StreamSubscription<bool>? _subscription;

  @override
  bool build() => true;

  void bind(NetworkConnectivitySource source) {
    state = source.isOnline;
    unawaited(_subscription?.cancel());
    _subscription = source.onOnlineChanged.listen(_handleOnlineChanged);
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      _subscription = null;
    });
  }

  void _handleOnlineChanged(bool isOnline) {
    state = isOnline;
    ref.read(backgroundSyncProvider.notifier).setConnectivity(isOnline: isOnline);
  }
}

final networkConnectivityProvider =
    NotifierProvider<NetworkConnectivityNotifier, bool>(
      NetworkConnectivityNotifier.new,
    );
