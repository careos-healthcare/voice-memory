import 'package:archiveme_mobile/features/capture/services/entry_save_pipeline.dart';
import 'package:archiveme_mobile/features/capture_flow/live_voice_session.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';

/// Immutable phases for the focused-beta capture state machine.
enum CaptureFlowPhase {
  ready,
  requestingPermission,
  recording,
  stopping,
  savingLocal,
  savedLocal,
  processingRemote,
  savedWithReflection,
  recoverableFailure,
}

/// Typed capture input mode on the strangler screen.
enum CaptureInputMode { voice, typed }

/// Kind of recoverable state surfaced to the user.
enum CaptureRecoveryKind {
  none,
  interruptedVoice,
  pendingTranscript,
}

/// Immutable snapshot consumed by [CaptureScreen] widgets.
class CaptureFlowSnapshot {
  const CaptureFlowSnapshot({
    required this.phase,
    this.inputMode = CaptureInputMode.voice,
    this.recordingDuration = Duration.zero,
    this.stageLabel,
    this.errorMessage,
    this.savedEntry,
    this.pipelineResult,
    this.entryCount = 0,
    this.hasLocalDraft = false,
    this.hasLocalSave = false,
    this.permissionBlocked = false,
    this.permissionRequiresSettings = false,
    this.microphoneGranted = false,
    this.attachToEntryId,
    this.recoveryKind = CaptureRecoveryKind.none,
    this.routineKind,
    this.routinePrompt,
    this.routinePromptDismissed = false,
    this.routinePromptLoading = false,
    this.transcriptionChoiceRequired = false,
    this.speechLocaleChoiceRequired = false,
    this.amplitudeBars = const [],
    this.recordingPaused = false,
    this.draftTranscript,
    this.deviceSaveVisible = false,
    this.conversationTurns = const [],
    this.chatLines = const [],
    this.liveSttRoute = LiveSttRoute.offline,
    this.attachedImages = const [],
  });

  final CaptureFlowPhase phase;
  final CaptureInputMode inputMode;
  final Duration recordingDuration;
  final String? stageLabel;
  final String? errorMessage;
  final JournalEntry? savedEntry;
  final CapturePipelineResult? pipelineResult;
  final int entryCount;
  final bool hasLocalDraft;
  final bool hasLocalSave;
  final bool permissionBlocked;
  final bool permissionRequiresSettings;

  /// True after a check finds the microphone already usable.
  final bool microphoneGranted;
  final String? attachToEntryId;
  final CaptureRecoveryKind recoveryKind;
  final JournalRoutineKind? routineKind;
  final RoutineJournalPrompt? routinePrompt;
  final bool routinePromptDismissed;
  final bool routinePromptLoading;

  /// Set when this device cannot transcribe locally and remote transcription is
  /// not permitted, so the customer has to be asked once which they want. Never
  /// set by a request failure — see [TranscriptionCapabilityPolicy].
  final bool transcriptionChoiceRequired;

  /// Set when this device can transcribe locally but has not been told which
  /// language to listen for, and remote transcription is not permitted.
  ///
  /// A separate flag from [transcriptionChoiceRequired] because the two ask
  /// different questions and only one of them is about privacy. Also never set
  /// by a request failure.
  final bool speechLocaleChoiceRequired;

  /// Last ~40 normalised levels for the live meter. Not the saved series.
  final List<double> amplitudeBars;

  final bool recordingPaused;

  /// On-screen partials only. Never written to [JournalEntry.transcript].
  final String? draftTranscript;

  /// User dictation lines for the live recording. Not saved.
  final List<LiveConversationTurn> conversationTurns;

  /// Reflect-with-me bubbles. Saved separately from the transcript.
  final List<VoiceChatLine> chatLines;

  /// Which listener is producing [draftTranscript].
  final LiveSttRoute liveSttRoute;

  /// Local image paths chosen before this moment is saved.
  final List<String> attachedImages;

  /// True once the recording file is accepted for a local save.
  final bool deviceSaveVisible;

  bool get showsRoutinePrompt =>
      !isAttachMode &&
      !routinePromptDismissed &&
      routinePrompt != null &&
      routinePrompt!.primaryPrompt.trim().isNotEmpty;

  bool get isAttachMode =>
      attachToEntryId != null && attachToEntryId!.trim().isNotEmpty;

  bool get isCapturing => phase == CaptureFlowPhase.recording;

  bool get showsPostSave =>
      phase == CaptureFlowPhase.savedLocal ||
      phase == CaptureFlowPhase.savedWithReflection;

  bool get isBusy =>
      phase == CaptureFlowPhase.requestingPermission ||
      phase == CaptureFlowPhase.stopping ||
      phase == CaptureFlowPhase.savingLocal ||
      phase == CaptureFlowPhase.processingRemote;

  CaptureFlowSnapshot copyWith({
    CaptureFlowPhase? phase,
    CaptureInputMode? inputMode,
    Duration? recordingDuration,
    String? stageLabel,
    String? errorMessage,
    JournalEntry? savedEntry,
    CapturePipelineResult? pipelineResult,
    int? entryCount,
    bool? hasLocalDraft,
    bool? hasLocalSave,
    bool? permissionBlocked,
    bool? permissionRequiresSettings,
    bool? microphoneGranted,
    String? attachToEntryId,
    CaptureRecoveryKind? recoveryKind,
    JournalRoutineKind? routineKind,
    RoutineJournalPrompt? routinePrompt,
    bool? routinePromptDismissed,
    bool? routinePromptLoading,
    bool? transcriptionChoiceRequired,
    bool? speechLocaleChoiceRequired,
    List<double>? amplitudeBars,
    bool? recordingPaused,
    String? draftTranscript,
    bool? deviceSaveVisible,
    List<LiveConversationTurn>? conversationTurns,
    List<VoiceChatLine>? chatLines,
    LiveSttRoute? liveSttRoute,
    List<String>? attachedImages,
    bool clearImages = false,
    bool clearDraft = false,
    bool clearRoutinePrompt = false,
    bool clearError = false,
    bool clearStage = false,
    bool clearSaved = false,
    bool clearPipeline = false,
  }) {
    return CaptureFlowSnapshot(
      phase: phase ?? this.phase,
      inputMode: inputMode ?? this.inputMode,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      stageLabel: clearStage ? null : (stageLabel ?? this.stageLabel),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      savedEntry: clearSaved ? null : (savedEntry ?? this.savedEntry),
      pipelineResult:
          clearPipeline ? null : (pipelineResult ?? this.pipelineResult),
      entryCount: entryCount ?? this.entryCount,
      hasLocalDraft: hasLocalDraft ?? this.hasLocalDraft,
      hasLocalSave: hasLocalSave ?? this.hasLocalSave,
      permissionBlocked: permissionBlocked ?? this.permissionBlocked,
      permissionRequiresSettings:
          permissionRequiresSettings ?? this.permissionRequiresSettings,
      microphoneGranted: microphoneGranted ?? this.microphoneGranted,
      attachToEntryId: attachToEntryId ?? this.attachToEntryId,
      recoveryKind: recoveryKind ?? this.recoveryKind,
      routineKind: routineKind ?? this.routineKind,
      routinePrompt:
          clearRoutinePrompt ? null : (routinePrompt ?? this.routinePrompt),
      routinePromptDismissed:
          routinePromptDismissed ?? this.routinePromptDismissed,
      routinePromptLoading: routinePromptLoading ?? this.routinePromptLoading,
      transcriptionChoiceRequired:
          transcriptionChoiceRequired ?? this.transcriptionChoiceRequired,
      speechLocaleChoiceRequired:
          speechLocaleChoiceRequired ?? this.speechLocaleChoiceRequired,
      amplitudeBars: amplitudeBars ?? this.amplitudeBars,
      recordingPaused: recordingPaused ?? this.recordingPaused,
      draftTranscript:
          clearDraft ? null : (draftTranscript ?? this.draftTranscript),
      deviceSaveVisible: deviceSaveVisible ?? this.deviceSaveVisible,
      conversationTurns: clearDraft
          ? const []
          : (conversationTurns ?? this.conversationTurns),
      chatLines: clearDraft ? const [] : (chatLines ?? this.chatLines),
      liveSttRoute: liveSttRoute ?? this.liveSttRoute,
      attachedImages: clearImages
          ? const []
          : (attachedImages ?? this.attachedImages),
    );
  }
}
