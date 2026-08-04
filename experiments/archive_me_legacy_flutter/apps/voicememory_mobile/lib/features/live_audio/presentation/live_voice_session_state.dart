import '../domain/models/live_session_state.dart';
import '../domain/models/live_voice_error_state.dart';
import '../../../models/local_capture_context.dart';
import 'live_voice_session_presentation.dart';

class LiveVoiceSessionState {
  const LiveVoiceSessionState({
    required this.phase,
    required this.sessionState,
    required this.errorState,
    this.seconds = 0,
    this.transcript = '',
    this.stageLabel = '',
    this.playbackQueueDepth = 0,
    this.busy = false,
    this.localCaptureContext,
    this.collectingAmbientContext = false,
  });

  final LiveVoiceUiPhase phase;
  final LiveSessionState sessionState;
  final LiveVoiceErrorState errorState;
  final int seconds;
  final String transcript;
  final String stageLabel;
  final int playbackQueueDepth;
  final bool busy;
  final LocalCaptureContext? localCaptureContext;
  final bool collectingAmbientContext;

  bool get hasError => errorState != LiveVoiceErrorState.none;
  bool get isSaving => phase == LiveVoiceUiPhase.saving;
  bool get showActions =>
      (phase == LiveVoiceUiPhase.active ||
          phase == LiveVoiceUiPhase.starting) &&
      !hasError;

  LiveVoiceVisualState get visualState =>
      LiveVoiceSessionPresentation.resolveVisualState(
        phase: phase,
        sessionState: sessionState,
        modelSpeaking: playbackQueueDepth > 0,
      );

  LiveVoiceSessionState copyWith({
    LiveVoiceUiPhase? phase,
    LiveSessionState? sessionState,
    LiveVoiceErrorState? errorState,
    int? seconds,
    String? transcript,
    String? stageLabel,
    int? playbackQueueDepth,
    bool? busy,
    LocalCaptureContext? localCaptureContext,
    bool clearLocalCaptureContext = false,
    bool? collectingAmbientContext,
  }) {
    return LiveVoiceSessionState(
      phase: phase ?? this.phase,
      sessionState: sessionState ?? this.sessionState,
      errorState: errorState ?? this.errorState,
      seconds: seconds ?? this.seconds,
      transcript: transcript ?? this.transcript,
      stageLabel: stageLabel ?? this.stageLabel,
      playbackQueueDepth: playbackQueueDepth ?? this.playbackQueueDepth,
      busy: busy ?? this.busy,
      localCaptureContext: clearLocalCaptureContext
          ? null
          : localCaptureContext ?? this.localCaptureContext,
      collectingAmbientContext:
          collectingAmbientContext ?? this.collectingAmbientContext,
    );
  }
}
