import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/record/quick_text_capture_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

class CaptureReadyPanel extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(context)
        .copyWith(color: AppColors.textSecondary, height: 1.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          MicrophonePermissionCopy.neededTitle,
          style: ArchiveMobileTypography.responsiveSectionTitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(MicrophonePermissionCopy.neededBody, style: bodyStyle),
        if (errorMessage != null && errorMessage!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(errorMessage!, style: bodyStyle.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (!attachMode)
          SegmentedButton<CaptureInputMode>(
            segments: const [
              ButtonSegment(value: CaptureInputMode.voice, label: Text('Voice')),
              ButtonSegment(value: CaptureInputMode.typed, label: Text('Type')),
            ],
            selected: {inputMode},
            onSelectionChanged: (selection) => onSwitchMode(selection.first),
          ),
        if (!attachMode) const SizedBox(height: AppSpacing.lg),
        if (!attachMode && inputMode == CaptureInputMode.voice)
          FilledButton(
            key: const Key('capture_start_voice'),
            onPressed: saving ? null : onStartVoice,
            child: Text(MicrophonePermissionCopy.requestMicrophoneCta),
          )
        else ...[
          TextField(
            key: const Key('capture_typed_field'),
            controller: typedController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: QuickTextCaptureCopy.focusedPlaceholder,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('capture_save_typed'),
            onPressed: saving
                ? null
                : () => onSaveTyped(typedController.text.trim()),
            child: const Text('Save moment'),
          ),
        ],
        if (permissionRequiresSettings) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(MicrophonePermissionCopy.statusBlocked, style: bodyStyle),
        ] else if (permissionBlocked) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(MicrophonePermissionCopy.typeInsteadBlockedHelper, style: bodyStyle),
        ],
      ],
    );
  }
}

class CaptureRecordingPanel extends StatelessWidget {
  const CaptureRecordingPanel({
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
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Container(
      decoration: VoiceMemoryCards.standard(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text(
            '$minutes:$seconds',
            key: const Key('capture_recording_timer'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('capture_stop_voice'),
            onPressed: onStop,
            child: Text(ConsumerUiCopy.stopRecordingCta),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
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
