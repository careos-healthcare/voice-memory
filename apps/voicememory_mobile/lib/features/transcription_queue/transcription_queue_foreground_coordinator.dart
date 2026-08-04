import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'transcription_queue_executor.dart';

typedef TranscriptionQueueDrain = Future<int> Function();

/// Opportunistically drains the durable queue while the app can do useful work.
final class TranscriptionQueueForegroundCoordinator {
  TranscriptionQueueForegroundCoordinator({
    TranscriptionQueueExecutor? executor,
    TranscriptionQueueDrain? drain,
    Stream<List<ConnectivityResult>>? connectivityChanges,
  }) : assert(executor != null || drain != null),
       _drain = drain ?? executor!.drain,
       _connectivityChanges =
           connectivityChanges ?? Connectivity().onConnectivityChanged;

  final TranscriptionQueueDrain _drain;
  final Stream<List<ConnectivityResult>> _connectivityChanges;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  AppLifecycleListener? _lifecycleListener;

  void start() {
    if (_connectivitySubscription != null) return;
    _connectivitySubscription = _connectivityChanges.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(_drain());
      }
    });
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(_drain()),
    );
    unawaited(_drain());
  }

  Future<void> dispose() async {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
