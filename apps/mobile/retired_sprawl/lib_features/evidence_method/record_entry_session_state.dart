import 'package:archiveme_mobile/features/evidence_method/evidence_insight.dart';

enum RecordEntryPhase {
  idle,
  connecting,
  recording,
  processing,
  generatingInsight,
  complete,
  error,
  backgroundPaused,
}

class RecordEntrySessionState {
  const RecordEntrySessionState({
    this.phase = RecordEntryPhase.idle,
    this.insight,
    this.transcript,
    this.errorMessage,
    this.captureScreenAttached = false,
    this.savedEncryptedAudioPath,
    this.isBrainDump = false,
    this.elapsedSeconds = 0,
    this.promptIndex = 0,
  });

  static const brainDumpMaxSeconds = 300;

  final RecordEntryPhase phase;
  final EvidenceInsight? insight;
  final String? transcript;
  final String? errorMessage;
  final bool captureScreenAttached;
  final String? savedEncryptedAudioPath;
  final bool isBrainDump;
  final int elapsedSeconds;
  final int promptIndex;

  bool get isRecording => phase == RecordEntryPhase.recording;
  bool get isProcessing =>
      phase == RecordEntryPhase.processing ||
      phase == RecordEntryPhase.generatingInsight;
  bool get isActiveCapture =>
      phase == RecordEntryPhase.connecting ||
      phase == RecordEntryPhase.recording ||
      phase == RecordEntryPhase.backgroundPaused;
  bool get blocksBackNavigation => isActiveCapture || isProcessing;
  bool get showGlobalRecordingOverlay =>
      isActiveCapture && !captureScreenAttached;
  double get brainDumpProgress =>
      (elapsedSeconds / brainDumpMaxSeconds).clamp(0.0, 1.0);

  RecordEntrySessionState copyWith({
    RecordEntryPhase? phase,
    EvidenceInsight? insight,
    String? transcript,
    String? errorMessage,
    bool? captureScreenAttached,
    String? savedEncryptedAudioPath,
    bool? isBrainDump,
    int? elapsedSeconds,
    int? promptIndex,
    bool clearInsight = false,
    bool clearTranscript = false,
    bool clearError = false,
    bool clearSavedEncryptedAudioPath = false,
  }) {
    return RecordEntrySessionState(
      phase: phase ?? this.phase,
      insight: clearInsight ? null : insight ?? this.insight,
      transcript: clearTranscript ? null : transcript ?? this.transcript,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      captureScreenAttached:
          captureScreenAttached ?? this.captureScreenAttached,
      savedEncryptedAudioPath: clearSavedEncryptedAudioPath
          ? null
          : savedEncryptedAudioPath ?? this.savedEncryptedAudioPath,
      isBrainDump: isBrainDump ?? this.isBrainDump,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      promptIndex: promptIndex ?? this.promptIndex,
    );
  }
}