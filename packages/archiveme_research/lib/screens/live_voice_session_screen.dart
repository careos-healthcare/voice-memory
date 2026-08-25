import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/activation/first_loop_activation_coordinator.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_audio_focus_gateway.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_audio_session_coordinator.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_voice_lifecycle_policy.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_voice_capture_service.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_voice_error_classifier.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_voice_error_state.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_voice_session_fault.dart';
import 'package:archiveme_mobile/features/live_audio/domain/services/live_pcm16_capture_source.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_pipeline_log.dart';
import 'package:archiveme_mobile/features/live_audio/presentation/live_voice_session_copy.dart';
import 'package:archiveme_mobile/features/live_audio/presentation/live_voice_session_presentation.dart';
import 'package:archiveme_mobile/features/live_audio/presentation/widgets/live_voice_error_boundary_overlay.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/live_voice/live_voice_connection_pill.dart';
import 'package:archiveme_mobile/widgets/live_voice/live_voice_status_card.dart';
import 'package:archiveme_mobile/widgets/live_voice/live_voice_transcript_preview.dart';
import 'package:archiveme_mobile/widgets/record/post_save_listening_card.dart';

class LiveVoiceSessionScreen extends StatefulWidget {
  const LiveVoiceSessionScreen({
    super.key,
    this.liveVoiceCapture,
    this.audioFocusGateway,
  });

  final LiveVoiceCaptureService? liveVoiceCapture;
  final LiveAudioFocusGateway? audioFocusGateway;

  @override
  State<LiveVoiceSessionScreen> createState() => _LiveVoiceSessionScreenState();
}

class _LiveVoiceSessionScreenState extends State<LiveVoiceSessionScreen>
    with WidgetsBindingObserver {
  late final LiveVoiceCaptureService _liveVoice;
  late final LiveAudioFocusGateway _audioFocusGateway;
  LiveVoiceUiPhase _phase = LiveVoiceUiPhase.starting;
  int _seconds = 0;
  String _transcript = '';
  String _stageLabel = '';
  var _playbackQueueDepth = 0;
  var _busy = false;

  StreamSubscription<int>? _durationSubscription;
  StreamSubscription<String>? _transcriptSubscription;
  StreamSubscription<LiveVoiceSessionFault>? _faultSubscription;
  StreamSubscription<int>? _queueDepthSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _liveVoice =
        widget.liveVoiceCapture ?? AppServices.instance.liveVoiceCapture;
    _audioFocusGateway =
        widget.audioFocusGateway ??
        LiveAudioFocusGateway(captureService: _liveVoice);
    _liveVoice.controller.addListener(_onControllerChanged);
    _durationSubscription = _liveVoice.durationSeconds.listen((seconds) {
      if (!mounted) return;
      setState(() => _seconds = seconds);
    });
    _transcriptSubscription = _liveVoice.transcriptUpdates.listen((text) {
      if (!mounted) return;
      setState(() => _transcript = text);
    });
    _faultSubscription = _liveVoice.sessionFaults.listen((_) {
      if (!mounted) return;
      setState(() => _phase = LiveVoiceUiPhase.error);
    });
    _queueDepthSubscription = _liveVoice.playbackQueueDepthStream.listen(
      _onPlaybackQueueDepth,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startSession());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _audioFocusGateway.updateAppLifecycle(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (LiveVoiceLifecyclePolicy.shouldPauseActiveSession(
          state: state,
          sessionActive: _liveVoice.isActive,
          hasError: _liveVoice.hasError,
          isSaving: _phase == LiveVoiceUiPhase.saving,
          isConnectingOrActive:
              _phase == LiveVoiceUiPhase.active ||
              _phase == LiveVoiceUiPhase.starting,
        )) {
          debugPrint(
            'ARCHIVEME_LIVE: App backgrounded, pausing active hardware capture',
          );
          LiveAudioPipelineLog.appLifecyclePaused();
          unawaited(_liveVoice.pauseLiveCapture());
        }
      case AppLifecycleState.resumed:
        if (LiveVoiceLifecyclePolicy.shouldAttemptCaptureResume(
          state: state,
          sessionActive: _liveVoice.isActive,
          hasError: _liveVoice.hasError,
          isSaving: _phase == LiveVoiceUiPhase.saving,
        )) {
          debugPrint(
            'ARCHIVEME_LIVE: App returned to foreground, evaluating restoration',
          );
          LiveAudioPipelineLog.appLifecycleResumed();
          unawaited(_audioFocusGateway.resumeCaptureIfPossible());
        }
      case AppLifecycleState.detached:
        LiveAudioPipelineLog.appLifecycleDetached();
        unawaited(_teardownForDetached());
    }
  }

  Future<void> _teardownForDetached() async {
    await _audioFocusGateway.dispose();
    await _liveVoice.terminateActiveSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveVoice.controller.removeListener(_onControllerChanged);
    unawaited(_durationSubscription?.cancel());
    unawaited(_transcriptSubscription?.cancel());
    unawaited(_faultSubscription?.cancel());
    unawaited(_queueDepthSubscription?.cancel());
    unawaited(_audioFocusGateway.dispose());
    unawaited(_liveVoice.terminateActiveSession());
    super.dispose();
  }

  LiveVoiceVisualState get _visualState =>
      LiveVoiceSessionPresentation.resolveVisualState(
        phase: _phase,
        sessionState: _liveVoice.controller.state,
        modelSpeaking: _playbackQueueDepth > 0,
      );

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onPlaybackQueueDepth(int depth) {
    if (!mounted) return;
    final previous = _playbackQueueDepth;
    if (_phase == LiveVoiceUiPhase.active && previous == 0 && depth > 0) {
      HapticFeedback.lightImpact();
    }
    setState(() => _playbackQueueDepth = depth);
  }

  Future<void> _startSession() async {
    setState(() {
      _phase = LiveVoiceUiPhase.starting;
      _seconds = 0;
      _transcript = '';
      _stageLabel = LiveVoiceSessionCopy.connecting;
    });
    try {
      await _audioFocusGateway.initializeAndRequestFocus();
      await _liveVoice.start();
      if (TrialMode.enabled) {
        await ActivationTracker.trackTrialRecordingStarted();
      }
      unawaited(FirstLoopActivationCoordinator.markRecordingStarted());
      if (!mounted) return;
      setState(() {
        _phase = LiveVoiceUiPhase.active;
        _stageLabel = LiveVoiceSessionCopy.listening;
      });
    } on LiveAudioSessionFailure catch (error) {
      if (!mounted) return;
      await _liveVoice.handleSessionFailure(
        classifyLiveVoiceFailure(error.message, error: error),
        reason: error.message,
      );
      setState(() => _phase = LiveVoiceUiPhase.error);
    } on LivePcm16CaptureException catch (error) {
      if (!mounted) return;
      await _liveVoice.handleSessionFailure(
        LiveVoiceErrorState.hardwareFailure,
        reason: error.message,
      );
      setState(() => _phase = LiveVoiceUiPhase.error);
    } catch (_) {
      if (!mounted) return;
      await _liveVoice.handleSessionFailure(
        LiveVoiceErrorState.unknown,
        reason: 'start_failed',
      );
      setState(() => _phase = LiveVoiceUiPhase.error);
    }
  }

  Future<void> _handleRetry() async {
    if (_busy) return;

    if (_liveVoice.isActive && _liveVoice.hasError) {
      setState(() {
        _busy = true;
        _phase = LiveVoiceUiPhase.starting;
        _stageLabel = LiveVoiceSessionCopy.reconnecting;
      });
      await _audioFocusGateway.reactivateFocus();
      await _liveVoice.retrySessionRecovery();
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (_liveVoice.hasError) {
          _phase = LiveVoiceUiPhase.error;
        } else {
          _phase = LiveVoiceUiPhase.active;
          _stageLabel = LiveVoiceSessionCopy.listening;
        }
      });
      return;
    }

    await _startSession();
  }

  Future<bool> _confirmDiscard() async {
    if (_phase == LiveVoiceUiPhase.saving || _busy) return false;
    if (_phase == LiveVoiceUiPhase.error) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(LiveVoiceSessionCopy.discardTitle),
        content: const Text(LiveVoiceSessionCopy.discardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(LiveVoiceSessionCopy.keepTalking),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(LiveVoiceSessionCopy.discardConfirm),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _handleExitSession() async {
    if (_busy) return;
    await _liveVoice.terminateActiveSession();
    if (!mounted) return;
    context.pop();
  }

  Future<void> _handleCancel() async {
    if (_busy) return;
    final discard = await _confirmDiscard();
    if (!discard || !mounted) return;
    await _liveVoice.cancel();
    if (!mounted) return;
    context.pop();
  }

  Future<void> _handleStopAndSave() async {
    if (_busy || !_liveVoice.isActive) return;
    setState(() {
      _busy = true;
      _phase = LiveVoiceUiPhase.saving;
      _stageLabel = LiveVoiceSessionCopy.savingTitle;
    });
    if (TrialMode.enabled) {
      await ActivationTracker.trackTrialSaveStarted();
    }
    try {
      final stageSubscription = _liveVoice.pipelineStates.listen((state) {
        if (!mounted) return;
        setState(() {
          _stageLabel = switch (state.stage) {
            PipelineStage.attesting => 'Connecting…',
            PipelineStage.transcribing => 'Saving transcript…',
            PipelineStage.analyzing => 'Finding patterns…',
            PipelineStage.saving => 'Saving…',
            PipelineStage.done => 'Done',
          };
        });
      });
      final result = await _liveVoice.stopAndSave();
      await stageSubscription.cancel();
      if (!mounted) return;
      context.pop(result);
    } on CapturePipelineFailure catch (_) {
      if (!mounted) return;
      await _liveVoice.handleSessionFailure(
        LiveVoiceErrorState.unknown,
        reason: 'save_failed',
      );
      setState(() {
        _busy = false;
        _phase = LiveVoiceUiPhase.error;
      });
    } catch (_) {
      if (!mounted) return;
      await _liveVoice.handleSessionFailure(
        LiveVoiceErrorState.unknown,
        reason: 'save_failed',
      );
      setState(() {
        _busy = false;
        _phase = LiveVoiceUiPhase.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleCancel();
      },
      child: ColoredBox(
        color: AppColors.backgroundPrimary,
        child: ListenableBuilder(
          listenable: _liveVoice,
          builder: (context, _) {
            final visualState = _visualState;
            final showActions =
                (_phase == LiveVoiceUiPhase.active ||
                    _phase == LiveVoiceUiPhase.starting) &&
                !_liveVoice.hasError;
            final showSaving = _phase == LiveVoiceUiPhase.saving;

            return SafeArea(
              child: Scaffold(
                backgroundColor: AppColors.backgroundPrimary,
                appBar: AppBar(
                  backgroundColor: AppColors.backgroundPrimary,
                  elevation: 0,
                  title: const Text(LiveVoiceSessionCopy.screenTitle),
                  actions: [LiveVoiceConnectionPill(visualState: visualState)],
                ),
                body: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              children: [
                                LiveVoiceStatusCard(
                                  visualState: visualState,
                                  seconds: _seconds,
                                  playbackQueueDepth: _playbackQueueDepth,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                if (showSaving) ...[
                                  PostSaveListeningCard(
                                    stageLabel: _stageLabel,
                                  ),
                                ] else ...[
                                  LiveVoiceTranscriptPreview(
                                    transcript: _transcript,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (showActions) ...[
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    key: const Key('live_voice_cancel_button'),
                                    onPressed: _busy
                                        ? null
                                        : () => unawaited(_handleCancel()),
                                    child: const Text(
                                      LiveVoiceSessionCopy.cancel,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  flex: 2,
                                  child: FilledButton.icon(
                                    key: const Key(
                                      'live_voice_stop_save_button',
                                    ),
                                    onPressed:
                                        (_busy ||
                                            _phase == LiveVoiceUiPhase.starting)
                                        ? null
                                        : () => unawaited(_handleStopAndSave()),
                                    icon: const Icon(Icons.stop),
                                    label: const Text(
                                      LiveVoiceSessionCopy.stopAndSave,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    LiveVoiceErrorBoundaryOverlay(
                      errorState: _liveVoice.errorState,
                      busy: _busy,
                      onRetry: () => unawaited(_handleRetry()),
                      onCancel: () => unawaited(_handleExitSession()),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
