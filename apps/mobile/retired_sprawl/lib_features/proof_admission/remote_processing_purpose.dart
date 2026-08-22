/// Typed remote-processing purposes for the focused beta capture flow.
enum RemoteProcessingPurpose {
  /// Send recorded audio to the backend for transcription.
  remoteTranscription,

  /// Send transcript text to the backend for reflection / analysis.
  remoteReflection,
}

extension RemoteProcessingPurposeStorage on RemoteProcessingPurpose {
  String get storageKey => switch (this) {
    RemoteProcessingPurpose.remoteTranscription => 'remote_transcription',
    RemoteProcessingPurpose.remoteReflection => 'remote_reflection',
  };

  static RemoteProcessingPurpose? fromStorageKey(String raw) {
    switch (raw.trim()) {
      case 'remote_transcription':
        return RemoteProcessingPurpose.remoteTranscription;
      case 'remote_reflection':
        return RemoteProcessingPurpose.remoteReflection;
      default:
        return null;
    }
  }

  /// Legacy v1 category tokens mapped to typed purposes.
  static RemoteProcessingPurpose? fromLegacyCategory(String raw) {
    switch (raw.trim()) {
      case 'transcription':
        return RemoteProcessingPurpose.remoteTranscription;
      case 'reflection_analysis':
        return RemoteProcessingPurpose.remoteReflection;
      default:
        return null;
    }
  }

  /// Purposes granted when the customer opts in during onboarding.
  static const Set<RemoteProcessingPurpose> onboardingGrant = {
    RemoteProcessingPurpose.remoteTranscription,
    RemoteProcessingPurpose.remoteReflection,
  };
}
