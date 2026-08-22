import 'dart:async';

import 'package:archiveme_mobile/features/live_audio/infrastructure/network_connectivity_source.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/provisional_transcript_reconciler.dart';

/// Re-runs server transcription when connectivity returns for provisional entries.
class ProvisionalTranscriptReconcileGateway {
  ProvisionalTranscriptReconcileGateway({
    required NetworkConnectivitySource connectivity,
    required ProvisionalTranscriptReconciler reconciler,
  }) : _reconciler = reconciler {
    _subscription = connectivity.onConnectivityRestored.listen((_) {
      unawaited(_reconciler.reconcileAll());
    });
  }

  final ProvisionalTranscriptReconciler _reconciler;
  StreamSubscription<void>? _subscription;

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}