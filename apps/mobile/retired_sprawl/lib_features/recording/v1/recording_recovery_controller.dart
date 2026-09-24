/// Tracks transcript and vault recovery offers independently from capture UI.
class RecordingRecoveryController {
  bool _pendingTranscriptRecoveryVisible = false;
  bool _vaultRecoveryScheduled = false;
  bool _interruptedCapture = false;

  bool get pendingTranscriptRecoveryVisible =>
      _pendingTranscriptRecoveryVisible;

  bool get vaultRecoveryScheduled => _vaultRecoveryScheduled;

  bool get interruptedCapture => _interruptedCapture;

  void showPendingTranscriptRecovery() {
    _pendingTranscriptRecoveryVisible = true;
  }

  void hidePendingTranscriptRecovery() {
    _pendingTranscriptRecoveryVisible = false;
  }

  void markVaultRecoveryScheduled() {
    _vaultRecoveryScheduled = true;
  }

  void clearVaultRecoveryScheduled() {
    _vaultRecoveryScheduled = false;
  }

  void markInterruptedCapture() {
    _interruptedCapture = true;
  }

  void clearInterruptedCapture() {
    _interruptedCapture = false;
  }

  void resetSession() {
    _pendingTranscriptRecoveryVisible = false;
    _vaultRecoveryScheduled = false;
    _interruptedCapture = false;
  }
}
