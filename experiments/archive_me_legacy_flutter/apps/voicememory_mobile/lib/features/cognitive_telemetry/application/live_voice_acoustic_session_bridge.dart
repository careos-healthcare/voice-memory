/// Acoustic capture context staged after live vault commit, consumed post-save.
class LiveVoiceAcousticSessionSnapshot {
  const LiveVoiceAcousticSessionSnapshot({
    required this.sessionId,
    required this.pitchContour,
  });

  final String sessionId;
  final List<double> pitchContour;
}

/// Bridges live-voice vault commit to journal save interceptors.
class LiveVoiceAcousticSessionBridge {
  LiveVoiceAcousticSessionSnapshot? _pending;

  void stageAfterVaultCommit({
    required String sessionId,
    required List<double> pitchContour,
  }) {
    _pending = LiveVoiceAcousticSessionSnapshot(
      sessionId: sessionId,
      pitchContour: List<double>.from(pitchContour),
    );
  }

  LiveVoiceAcousticSessionSnapshot? consumePending() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  void clear() {
    _pending = null;
  }
}
