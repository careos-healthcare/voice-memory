/// Server-backed transcript lifecycle for voice captures.
enum TranscriptStatus {
  /// Authoritative server (or fully verified) transcript.
  finalTranscript('final'),

  /// On-device native STT — awaiting server re-transcription.
  provisional('provisional'),

  /// No usable transcript yet (draft / placeholder).
  pending('pending');

  const TranscriptStatus(this.storageValue);

  final String storageValue;

  static TranscriptStatus fromStorage(String? raw) {
    switch (raw) {
      case 'provisional':
        return TranscriptStatus.provisional;
      case 'pending':
        return TranscriptStatus.pending;
      case 'final':
      default:
        return TranscriptStatus.finalTranscript;
    }
  }

  bool get isProvisional => this == TranscriptStatus.provisional;
  bool get isPending => this == TranscriptStatus.pending;
  bool get isFinal => this == TranscriptStatus.finalTranscript;
}