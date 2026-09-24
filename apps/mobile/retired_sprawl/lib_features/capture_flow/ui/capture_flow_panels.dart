import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/daily_check_in/daily_check_in_card.dart';
import 'package:archiveme_mobile/features/recording/streaming_transcript_session.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/routine_prompt_card.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/record/quick_text_capture_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/writing_canvas_theme.dart';
import 'package:archiveme_mobile/widgets/record/recording_waveform.dart';
import 'package:archiveme_mobile/widgets/record/recording_waveform_controller.dart';
import 'package:archiveme_mobile/widgets/record/streaming_transcript_text.dart';
import 'package:archiveme_mobile/widgets/writing_canvas/writing_canvas_chrome.dart';
import 'package:archiveme_mobile/widgets/writing_canvas/writing_canvas_press.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CaptureReadyPanel extends StatefulWidget {
  const CaptureReadyPanel({
    required this.inputMode,
    required this.attachMode,
    required this.onStartVoice,
    required this.onSaveTyped,
    required this.onSwitchMode,
    required this.permissionBlocked,
    required this.permissionRequiresSettings,
    required this.errorMessage,
    required this.typedController,
    required this.saving,
    this.routinePrompt,
    this.routinePromptLoading = false,
    this.onSelectRoutinePrompt,
    this.onDismissRoutinePrompt,
    super.key,
  });

  final CaptureInputMode inputMode;
  final bool attachMode;
  final VoidCallback onStartVoice;
  final ValueChanged<String> onSaveTyped;
  final ValueChanged<CaptureInputMode> onSwitchMode;
  final bool permissionBlocked;
  final bool permissionRequiresSettings;
  final String? errorMessage;
  final TextEditingController typedController;
  final bool saving;
  final RoutineJournalPrompt? routinePrompt;
  final bool routinePromptLoading;
  final ValueChanged<String>? onSelectRoutinePrompt;
  final VoidCallback? onDismissRoutinePrompt;

  @override
  State<CaptureReadyPanel> createState() => _CaptureReadyPanelState();
}

class _CaptureReadyPanelState extends State<CaptureReadyPanel> {
  late final WritingCanvasChromeController _chrome;
  final _typedFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _chrome = WritingCanvasChromeController(
      idleRestore: WritingCanvasTheme.light.idleRestore,
    );
    widget.typedController.addListener(_syncChrome);
    _typedFocus.addListener(_syncChrome);
  }

  @override
  void didUpdateWidget(CaptureReadyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.typedController != widget.typedController) {
      oldWidget.typedController.removeListener(_syncChrome);
      widget.typedController.addListener(_syncChrome);
    }
  }

  @override
  void dispose() {
    widget.typedController.removeListener(_syncChrome);
    _typedFocus.dispose();
    _chrome.dispose();
    super.dispose();
  }

  void _syncChrome() {
    _chrome.onTyped(
      hasText: widget.typedController.text.trim().isNotEmpty,
      focused: _typedFocus.hasFocus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvas = WritingCanvasTheme.of(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    // All children are intrinsically sized (no Expanded/Spacer/Flexible), so a
    // scroll wrap is safe. Required: 200% text scale overflows a short screen.
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        final delta = notification.scrollDelta;
        if (delta != null) _chrome.onScrollDelta(delta);
        return false;
      },
      child: SingleChildScrollView(
        key: const Key('capture_ready_scroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WritingCanvasChromeFade(
              controller: _chrome,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.routinePromptLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.lg),
                      child: LinearProgressIndicator(minHeight: 2),
                    )
                  else if (widget.routinePrompt != null &&
                      widget.onSelectRoutinePrompt != null &&
                      widget.onDismissRoutinePrompt != null) ...[
                    RoutinePromptCard(
                      prompt: widget.routinePrompt!,
                      onSelectPrompt: widget.onSelectRoutinePrompt!,
                      onDismiss: widget.onDismissRoutinePrompt!,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Text(
                    MicrophonePermissionCopy.neededTitle,
                    style: ArchiveMobileTypography.responsiveSectionTitle(
                      context,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(MicrophonePermissionCopy.neededBody, style: bodyStyle),
                  if (widget.errorMessage != null &&
                      widget.errorMessage!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.errorMessage!,
                      style: bodyStyle.copyWith(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!widget.attachMode)
              SegmentedButton<CaptureInputMode>(
                segments: const [
                  ButtonSegment(
                    value: CaptureInputMode.voice,
                    label: Text('Voice'),
                  ),
                  ButtonSegment(
                    value: CaptureInputMode.typed,
                    label: Text('Type'),
                  ),
                ],
                selected: {widget.inputMode},
                onSelectionChanged: (selection) {
                  WritingCanvasPress.wrap(
                    () => widget.onSwitchMode(selection.first),
                  )?.call();
                },
              ),
            if (!widget.attachMode) const SizedBox(height: AppSpacing.lg),
            if (!widget.attachMode &&
                widget.inputMode == CaptureInputMode.voice)
              WritingCanvasSpringHost(
                child: FilledButton(
                  key: const Key('capture_start_voice'),
                  onPressed: WritingCanvasPress.wrap(
                    widget.saving ? null : widget.onStartVoice,
                  ),
                  child: Text(MicrophonePermissionCopy.requestMicrophoneCta),
                ),
              )
            else ...[
              TextField(
                key: const Key('capture_typed_field'),
                controller: widget.typedController,
                focusNode: _typedFocus,
                maxLines: 4,
                style: canvas.textStyle,
                decoration: InputDecoration(
                  hintText:
                      widget.routinePrompt?.primaryPrompt.trim().isNotEmpty ==
                          true
                      ? widget.routinePrompt!.primaryPrompt
                      : QuickTextCaptureCopy.focusedPlaceholder,
                  border: const OutlineInputBorder(),
                  contentPadding: canvas.contentPadding,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              WritingCanvasSpringHost(
                child: FilledButton(
                  key: const Key('capture_save_typed'),
                  onPressed: WritingCanvasPress.wrap(
                    widget.saving
                        ? null
                        : () => widget.onSaveTyped(
                            widget.typedController.text.trim(),
                          ),
                  ),
                  child: const Text('Save moment'),
                ),
              ),
            ],
            WritingCanvasChromeFade(
              controller: _chrome,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.permissionRequiresSettings) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      MicrophonePermissionCopy.statusBlocked,
                      style: bodyStyle,
                    ),
                  ] else if (widget.permissionBlocked) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      MicrophonePermissionCopy.typeInsteadBlockedHelper,
                      style: bodyStyle,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  const DailyCheckInCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CaptureRecordingPanel extends StatefulWidget {
  const CaptureRecordingPanel({
    required this.duration,
    required this.onStop,
    required this.onCancel,
    super.key,
    this.waveformController,
    this.transcript = '',
  });

  final Duration duration;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final RecordingWaveformController? waveformController;
  final String transcript;

  @override
  State<CaptureRecordingPanel> createState() => _CaptureRecordingPanelState();
}

class _CaptureRecordingPanelState extends State<CaptureRecordingPanel> {
  RecordingWaveformController? _ownedWaveform;

  RecordingWaveformController get _waveform =>
      widget.waveformController ?? _ownedWaveform!;

  @override
  void initState() {
    super.initState();
    if (widget.waveformController == null) {
      _ownedWaveform = RecordingWaveformController();
    }
  }

  @override
  void dispose() {
    _ownedWaveform?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = widget.duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = widget.duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final ink = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecordingWaveform(controller: _waveform, height: 88),
        const SizedBox(height: AppSpacing.sm),
        StreamingTranscriptText(text: widget.transcript),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '$minutes:$seconds',
          key: const Key('capture_recording_timer'),
          style: ArchiveMobileTypography.responsiveSectionTitle(
            context,
          ).copyWith(color: ink.withValues(alpha: 0.72)),
        ),
        const SizedBox(height: AppSpacing.md),
        WritingCanvasSpringHost(
          child: FilledButton(
            key: const Key('capture_stop_voice'),
            onPressed: WritingCanvasPress.wrap(widget.onStop),
            child: Text(ConsumerUiCopy.stopRecordingCta),
          ),
        ),
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
      ],
    );
  }
}

/// Uses the live microphone waveform when a provider scope is present.
class CaptureLiveRecordingSurface extends StatelessWidget {
  const CaptureLiveRecordingSurface({
    required this.duration,
    required this.onStop,
    required this.onCancel,
    super.key,
  });

  final Duration duration;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (!_captureHasProviderScope(context)) {
      return CaptureRecordingPanel(
        duration: duration,
        onStop: onStop,
        onCancel: onCancel,
      );
    }
    return _ScopedCaptureRecording(
      duration: duration,
      onStop: onStop,
      onCancel: onCancel,
    );
  }
}

class _ScopedCaptureRecording extends ConsumerWidget {
  const _ScopedCaptureRecording({
    required this.duration,
    required this.onStop,
    required this.onCancel,
  });

  final Duration duration;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcript = ref.watch(streamingTranscriptProvider);
    return CaptureRecordingPanel(
      duration: duration,
      onStop: onStop,
      onCancel: onCancel,
      waveformController: ref.read(recordingWaveformControllerProvider),
      transcript: transcript,
    );
  }
}

/// Keeps arrived words on screen while the rest of the capture finishes.
class StreamingTranscriptSlot extends StatelessWidget {
  const StreamingTranscriptSlot({super.key});

  @override
  Widget build(BuildContext context) {
    if (!_captureHasProviderScope(context)) return const SizedBox.shrink();
    return const _ScopedTranscriptSlot();
  }
}

class _ScopedTranscriptSlot extends ConsumerWidget {
  const _ScopedTranscriptSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcript = ref.watch(streamingTranscriptProvider);
    if (transcript.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: StreamingTranscriptText(text: transcript),
    );
  }
}

bool _captureHasProviderScope(BuildContext context) {
  return context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
      context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
          null;
}

class CaptureBusyPanel extends StatelessWidget {
  const CaptureBusyPanel({required this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircularProgressIndicator(),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(label!, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class CaptureFailurePanel extends StatelessWidget {
  const CaptureFailurePanel({
    required this.message,
    required this.hasLocalSave,
    required this.onRetry,
    required this.onDismiss,
    super.key,
  });

  final String message;
  final bool hasLocalSave;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: VoiceMemoryCards.standard(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          if (hasLocalSave)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Your moment is saved on this device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (onRetry != null)
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          TextButton(onPressed: onDismiss, child: const Text('Back')),
        ],
      ),
    );
  }
}
