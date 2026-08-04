import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/trial_mode.dart';
import '../../../models/local_capture_context.dart';
import '../../../services/app_services_providers.dart';
import '../../../services/capture_pipeline_service.dart';
import '../../activation/activation_tracker.dart';
import '../../activation/first_loop_activation_coordinator.dart';
import '../application/live_audio_focus_gateway.dart';
import '../application/live_audio_session_coordinator.dart';
import '../application/live_voice_capture_service.dart';
import '../application/live_voice_lifecycle_rules.dart';
import '../domain/models/live_voice_error_classifier.dart';
import '../domain/models/live_voice_error_state.dart';
import '../domain/models/live_voice_session_fault.dart';
import '../domain/services/live_pcm16_capture_source.dart';
import '../infrastructure/live_audio_pipeline_log.dart';
import 'live_voice_session_copy.dart';
import 'live_voice_session_presentation.dart';
import 'live_voice_session_state.dart';

final liveVoiceSessionControllerProvider = NotifierProvider.autoDispose(
  LiveVoiceSessionController.new,
);

class LiveVoiceSessionController extends Notifier<LiveVoiceSessionState> {
  late final LiveVoiceCaptureService _capture;
  late final LiveAudioFocusGateway _focus;
  final _subscriptions = <StreamSubscription<Object?>>[];
  AppLifecycleListener? _lifecycleListener;

  @override
  LiveVoiceSessionState build() {
    _capture = ref.watch(liveVoiceCaptureProvider);
    _focus = ref.watch(liveAudioFocusGatewayProvider);

    _capture.controller.addListener(_syncServiceSnapshot);
    _capture.addListener(_syncServiceSnapshot);
    _subscriptions
      ..add(_capture.durationSeconds.listen(_onDuration))
      ..add(_capture.transcriptUpdates.listen(_onTranscript))
      ..add(_capture.sessionFaults.listen(_onFault))
      ..add(_capture.playbackQueueDepthStream.listen(_onQueueDepth));

    _lifecycleListener = ref.read(appLifecycleListenerFactoryProvider)(
      onStateChange: handleLifecycle,
    );
    ref.onDispose(_dispose);

    return LiveVoiceSessionState(
      phase: LiveVoiceUiPhase.starting,
      sessionState: _capture.controller.state,
      errorState: _capture.errorState,
      stageLabel: LiveVoiceSessionCopy.connecting,
      playbackQueueDepth: _capture.playbackQueueDepth,
    );
  }

  void _onDuration(int seconds) {
    if (!ref.mounted || seconds == state.seconds) return;
    state = state.copyWith(seconds: seconds);
  }

  void _onTranscript(String transcript) {
    if (!ref.mounted || transcript == state.transcript) return;
    state = state.copyWith(transcript: transcript);
  }

  void _onFault(LiveVoiceSessionFault fault) {
    if (!ref.mounted) return;
    state = state.copyWith(
      phase: LiveVoiceUiPhase.error,
      errorState: _capture.errorState,
    );
  }

  void _onQueueDepth(int depth) {
    if (!ref.mounted || depth == state.playbackQueueDepth) return;
    state = state.copyWith(playbackQueueDepth: depth);
  }

  void _syncServiceSnapshot() {
    if (!ref.mounted) return;
    final sessionState = _capture.controller.state;
    final errorState = _capture.errorState;
    if (sessionState == state.sessionState && errorState == state.errorState) {
      return;
    }
    state = state.copyWith(
      sessionState: sessionState,
      errorState: errorState,
      phase: errorState == LiveVoiceErrorState.none
          ? state.phase
          : LiveVoiceUiPhase.error,
    );
  }

  Future<void> start() async {
    if (state.busy || _capture.isActive) return;
    state = state.copyWith(
      phase: LiveVoiceUiPhase.starting,
      seconds: 0,
      transcript: '',
      stageLabel: LiveVoiceSessionCopy.connecting,
      errorState: _capture.errorState,
    );
    try {
      await _focus.initializeAndRequestFocus();
      await _capture.start();
      if (TrialMode.enabled) {
        await ActivationTracker.trackTrialRecordingStarted();
      }
      unawaited(FirstLoopActivationCoordinator.markRecordingStarted());
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: LiveVoiceUiPhase.active,
        stageLabel: LiveVoiceSessionCopy.listening,
        sessionState: _capture.controller.state,
        errorState: _capture.errorState,
      );
    } on LiveAudioSessionFailure catch (error) {
      await _failStart(
        classifyLiveVoiceFailure(error.message, error: error),
        error.message,
      );
    } on LivePcm16CaptureException catch (error) {
      await _failStart(LiveVoiceErrorState.hardwareFailure, error.message);
    } catch (_) {
      await _failStart(LiveVoiceErrorState.unknown, 'start_failed');
    }
  }

  Future<void> _failStart(LiveVoiceErrorState error, String reason) async {
    await _capture.handleSessionFailure(error, reason: reason);
    if (!ref.mounted) return;
    state = state.copyWith(
      phase: LiveVoiceUiPhase.error,
      errorState: _capture.errorState,
    );
  }

  Future<void> retry() async {
    if (state.busy) return;
    if (!_capture.isActive || !_capture.hasError) {
      await start();
      return;
    }

    state = state.copyWith(
      busy: true,
      phase: LiveVoiceUiPhase.starting,
      stageLabel: LiveVoiceSessionCopy.reconnecting,
    );
    try {
      await _focus.reactivateFocus();
      await _capture.retrySessionRecovery();
      if (!ref.mounted) return;
      state = state.copyWith(
        busy: false,
        phase: _capture.hasError
            ? LiveVoiceUiPhase.error
            : LiveVoiceUiPhase.active,
        stageLabel: _capture.hasError
            ? state.stageLabel
            : LiveVoiceSessionCopy.listening,
        errorState: _capture.errorState,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        busy: false,
        phase: LiveVoiceUiPhase.error,
        errorState: _capture.errorState,
      );
    }
  }

  Future<CapturePipelineResult?> stopAndSave({
    LocalCaptureContext? localCaptureContext,
  }) async {
    if (state.busy || !_capture.isActive) return null;
    state = state.copyWith(
      busy: true,
      phase: LiveVoiceUiPhase.saving,
      stageLabel: LiveVoiceSessionCopy.savingTitle,
    );
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialSaveStarted();
    }
    try {
      return await _capture.stopAndSave(
        localCaptureContext: localCaptureContext ?? state.localCaptureContext,
        onStage: _onPipelineStage,
      );
    } catch (_) {
      await _capture.handleSessionFailure(
        LiveVoiceErrorState.unknown,
        reason: 'save_failed',
      );
      if (ref.mounted) {
        state = state.copyWith(
          busy: false,
          phase: LiveVoiceUiPhase.error,
          errorState: _capture.errorState,
        );
      }
      return null;
    }
  }

  Future<LocalCaptureContext?> collectAmbientContext({
    required bool includeLocation,
    required bool includeCalendarEvent,
    bool requestPermissions = true,
  }) async {
    if (state.collectingAmbientContext) return state.localCaptureContext;
    state = state.copyWith(collectingAmbientContext: true);
    final metadata = await ref
        .read(ambientContextServiceProvider)
        .collect(
          includeLocation: includeLocation,
          includeCalendarEvent: includeCalendarEvent,
          requestPermissions: requestPermissions,
        );
    if (!ref.mounted) return metadata;
    state = state.copyWith(
      localCaptureContext: metadata,
      clearLocalCaptureContext: metadata == null,
      collectingAmbientContext: false,
    );
    return metadata;
  }

  void clearAmbientContext() {
    state = state.copyWith(clearLocalCaptureContext: true);
  }

  void _onPipelineStage(PipelineStage stage) {
    if (!ref.mounted) return;
    state = state.copyWith(
      stageLabel: switch (stage) {
        PipelineStage.attesting => 'Connecting…',
        PipelineStage.transcribing => 'Saving transcript…',
        PipelineStage.analyzing => 'Finding patterns…',
        PipelineStage.saving => 'Saving…',
        PipelineStage.done => 'Done',
      },
    );
  }

  Future<void> cancel() => _capture.cancel();

  Future<void> terminate() => _capture.terminateActiveSession();

  void handleLifecycle(AppLifecycleState lifecycleState) {
    _focus.updateAppLifecycle(lifecycleState);
    switch (lifecycleState) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (LiveVoiceLifecycleRules.shouldPauseActiveSession(
          state: lifecycleState,
          sessionActive: _capture.isActive,
          hasError: _capture.hasError,
          isSaving: state.phase == LiveVoiceUiPhase.saving,
          isConnectingOrActive:
              state.phase == LiveVoiceUiPhase.active ||
              state.phase == LiveVoiceUiPhase.starting,
        )) {
          LiveAudioPipelineLog.appLifecyclePaused();
          unawaited(_capture.pauseLiveCapture());
        }
      case AppLifecycleState.resumed:
        if (LiveVoiceLifecycleRules.shouldAttemptCaptureResume(
          state: lifecycleState,
          sessionActive: _capture.isActive,
          hasError: _capture.hasError,
          isSaving: state.phase == LiveVoiceUiPhase.saving,
        )) {
          LiveAudioPipelineLog.appLifecycleResumed();
          unawaited(_focus.resumeCaptureIfPossible());
        }
      case AppLifecycleState.detached:
        LiveAudioPipelineLog.appLifecycleDetached();
        unawaited(terminate());
    }
  }

  void _dispose() {
    _capture.controller.removeListener(_syncServiceSnapshot);
    _capture.removeListener(_syncServiceSnapshot);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _lifecycleListener?.dispose();
    unawaited(_focus.dispose());
    unawaited(_capture.terminateActiveSession());
  }
}
