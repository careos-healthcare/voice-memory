/// Immutable view state for the V1 Record capture journey.
///
/// Split from the legacy record screen so timer/visualizer rebuilds stay narrow
/// while persistence and processing remain explicit in dedicated controllers.
enum RecordViewPhase {
  idle,
  requestingPermission,
  ready,
  recording,
  paused,
  processing,
  locallySaved,
  verifiedResultAvailable,
  localOnlyResult,
  recoverableError,
}

class RecordViewState {
  const RecordViewState({
    required this.phase,
    this.recordingDuration = Duration.zero,
    this.statusMessage,
    this.errorMessage,
    this.savedEntryId,
    this.hasVerifiedProof = false,
  });

  final RecordViewPhase phase;
  final Duration recordingDuration;
  final String? statusMessage;
  final String? errorMessage;
  final String? savedEntryId;
  final bool hasVerifiedProof;

  bool get isCapturing =>
      phase == RecordViewPhase.recording || phase == RecordViewPhase.paused;

  bool get showsPostSave =>
      phase == RecordViewPhase.locallySaved ||
      phase == RecordViewPhase.verifiedResultAvailable ||
      phase == RecordViewPhase.localOnlyResult;

  RecordViewState copyWith({
    RecordViewPhase? phase,
    Duration? recordingDuration,
    String? statusMessage,
    String? errorMessage,
    String? savedEntryId,
    bool? hasVerifiedProof,
  }) {
    return RecordViewState(
      phase: phase ?? this.phase,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      savedEntryId: savedEntryId ?? this.savedEntryId,
      hasVerifiedProof: hasVerifiedProof ?? this.hasVerifiedProof,
    );
  }
}