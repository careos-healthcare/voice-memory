import 'dart:async';

import 'package:flutter/widgets.dart';

enum InterruptionReason { phoneCallOrSystem, appBackgrounded, routeChange }

abstract class AudioRecordingOrchestrator {
  bool get isRecording;

  Future<void> pauseOrSaveDraftOnInterruption(InterruptionReason reason);
}

/// Persists active recording buffers before app lifecycle or native audio
/// interruptions can revoke access to audio hardware.
class AudioInterruptionHandler with WidgetsBindingObserver {
  AudioInterruptionHandler({
    required this.orchestrator,
    this.interruptionEvents,
  });

  final AudioRecordingOrchestrator orchestrator;

  /// Optional bridge for native audio-session and route-change events.
  final Stream<InterruptionReason>? interruptionEvents;

  StreamSubscription<InterruptionReason>? _interruptionSubscription;
  bool _isObserving = false;
  bool _appLifecycleInterruptionHandled = false;
  bool _interruptionInFlight = false;

  void startListening() {
    if (_isObserving) return;
    WidgetsBinding.instance.addObserver(this);
    _interruptionSubscription = interruptionEvents?.listen(_handleInterruption);
    _isObserving = true;
  }

  void stopListening() {
    if (!_isObserving) return;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_interruptionSubscription?.cancel());
    _interruptionSubscription = null;
    _isObserving = false;
    _appLifecycleInterruptionHandled = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appLifecycleInterruptionHandled = false;
      return;
    }

    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused) {
      return;
    }
    if (_appLifecycleInterruptionHandled) return;

    _appLifecycleInterruptionHandled = true;
    unawaited(_handleInterruption(InterruptionReason.appBackgrounded));
  }

  Future<void> _handleInterruption(InterruptionReason reason) async {
    if (_interruptionInFlight || !orchestrator.isRecording) return;

    _interruptionInFlight = true;
    try {
      await orchestrator.pauseOrSaveDraftOnInterruption(reason);
    } finally {
      _interruptionInFlight = false;
    }
  }
}
