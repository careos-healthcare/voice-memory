import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/live_audio/application/live_audio_focus_gateway.dart';
import '../features/live_audio/application/live_voice_capture_service.dart';
import '../features/live_audio/presentation/live_voice_session_controller.dart';
import '../features/live_audio/presentation/live_voice_session_copy.dart';
import '../features/live_audio/presentation/live_voice_session_presentation.dart';
import '../features/live_audio/presentation/live_voice_session_state.dart';
import '../features/live_audio/presentation/widgets/live_voice_error_boundary_overlay.dart';
import '../services/app_services_providers.dart';
import '../services/ambient_metadata_collector.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/live_voice/live_voice_connection_pill.dart';
import '../widgets/live_voice/live_voice_status_card.dart';
import '../widgets/live_voice/live_voice_transcript_preview.dart';
import '../widgets/record/post_save_listening_card.dart';
import '../widgets/record/ambient_context_control.dart';

class LiveVoiceSessionScreen extends StatelessWidget {
  const LiveVoiceSessionScreen({
    super.key,
    this.liveVoiceCapture,
    this.audioFocusGateway,
    this.ambientContextService,
  });

  final LiveVoiceCaptureService? liveVoiceCapture;
  final LiveAudioFocusGateway? audioFocusGateway;
  final AmbientContextService? ambientContextService;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        if (liveVoiceCapture != null)
          liveVoiceCaptureProvider.overrideWithValue(liveVoiceCapture!),
        if (audioFocusGateway != null)
          liveAudioFocusGatewayProvider.overrideWithValue(audioFocusGateway!),
        if (ambientContextService != null)
          ambientContextServiceProvider.overrideWithValue(
            ambientContextService!,
          ),
      ],
      child: const _LiveVoiceSessionView(),
    );
  }
}

class _LiveVoiceSessionView extends ConsumerStatefulWidget {
  const _LiveVoiceSessionView();

  @override
  ConsumerState<_LiveVoiceSessionView> createState() =>
      _LiveVoiceSessionViewState();
}

class _LiveVoiceSessionViewState extends ConsumerState<_LiveVoiceSessionView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(liveVoiceSessionControllerProvider.notifier);
      unawaited(controller.start());
      unawaited(
        controller.collectAmbientContext(
          includeLocation: true,
          includeCalendarEvent: true,
          requestPermissions: false,
        ),
      );
    });
  }

  Future<bool> _confirmDiscard(LiveVoiceSessionState session) async {
    if (session.isSaving || session.busy) return false;
    if (session.phase == LiveVoiceUiPhase.error) return true;
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

  Future<void> _cancel(LiveVoiceSessionState session) async {
    if (session.busy) return;
    if (!await _confirmDiscard(session) || !mounted) return;
    await ref.read(liveVoiceSessionControllerProvider.notifier).cancel();
    if (mounted) context.pop();
  }

  Future<void> _exit() async {
    final controller = ref.read(liveVoiceSessionControllerProvider.notifier);
    if (ref.read(liveVoiceSessionControllerProvider).busy) return;
    await controller.terminate();
    if (mounted) context.pop();
  }

  Future<void> _stopAndSave() async {
    final result = await ref
        .read(liveVoiceSessionControllerProvider.notifier)
        .stopAndSave();
    if (result != null && mounted) context.pop(result);
  }

  Future<void> _addAmbientContext() async {
    final request = await showAmbientContextConsentSheet(context);
    if (request == null || !mounted) return;
    final metadata = await ref
        .read(liveVoiceSessionControllerProvider.notifier)
        .collectAmbientContext(
          includeLocation: request.includeLocation,
          includeCalendarEvent: request.includeCalendarEvent,
        );
    if (!mounted) return;
    if (metadata == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No local context was available. Your recording can still be saved.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      liveVoiceSessionControllerProvider.select(
        (session) => session.playbackQueueDepth,
      ),
      (previous, next) {
        final phase = ref.read(liveVoiceSessionControllerProvider).phase;
        if (phase == LiveVoiceUiPhase.active &&
            (previous ?? 0) == 0 &&
            next > 0) {
          unawaited(HapticFeedback.lightImpact());
        }
      },
    );

    final session = ref.watch(liveVoiceSessionControllerProvider);
    final capture = ref.watch(liveVoiceCaptureProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _cancel(session);
      },
      child: ColoredBox(
        color: AppColors.backgroundPrimary,
        child: SafeArea(
          child: Scaffold(
            backgroundColor: AppColors.backgroundPrimary,
            appBar: AppBar(
              backgroundColor: AppColors.backgroundPrimary,
              elevation: 0,
              title: const Text(LiveVoiceSessionCopy.screenTitle),
              actions: [
                LiveVoiceConnectionPill(visualState: session.visualState),
              ],
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
                              visualState: session.visualState,
                              seconds: session.seconds,
                              playbackQueueDepth: session.playbackQueueDepth,
                              playbackPlayer: capture.playbackPlayer,
                              pitchContour: capture.playbackPitchContour,
                              audioDecibels: capture.audioDecibels,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (session.isSaving)
                              PostSaveListeningCard(
                                stageLabel: session.stageLabel,
                              )
                            else
                              LiveVoiceTranscriptPreview(
                                transcript: session.transcript,
                              ),
                          ],
                        ),
                      ),
                      if (session.showActions) ...[
                        const SizedBox(height: AppSpacing.md),
                        AmbientContextControl(
                          contextMetadata: session.localCaptureContext,
                          loading: session.collectingAmbientContext,
                          onAdd: () => unawaited(_addAmbientContext()),
                          onClear: () => ref
                              .read(liveVoiceSessionControllerProvider.notifier)
                              .clearAmbientContext(),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('live_voice_cancel_button'),
                                onPressed: session.busy
                                    ? null
                                    : () => unawaited(_cancel(session)),
                                child: const Text(LiveVoiceSessionCopy.cancel),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                key: const Key('live_voice_stop_save_button'),
                                onPressed:
                                    session.busy ||
                                        session.collectingAmbientContext ||
                                        session.phase ==
                                            LiveVoiceUiPhase.starting
                                    ? null
                                    : () => unawaited(_stopAndSave()),
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
                  errorState: session.errorState,
                  busy: session.busy,
                  onRetry: () => unawaited(
                    ref
                        .read(liveVoiceSessionControllerProvider.notifier)
                        .retry(),
                  ),
                  onCancel: () => unawaited(_exit()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
