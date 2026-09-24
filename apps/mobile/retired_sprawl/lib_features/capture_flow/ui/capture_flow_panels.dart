import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/record/example_prompt_catalog.dart';
import 'package:archiveme_mobile/record/quick_text_capture_copy.dart';
import 'package:archiveme_mobile/theme/app_palette.dart';
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
    required this.microphoneGranted,
    required this.errorMessage,
    required this.typedController,
    required this.saving,
    this.routinePrompt,
    this.routinePromptLoading = false,
    this.onSelectRoutinePrompt,
    this.onDismissRoutinePrompt,
    this.onPromptContext,
    this.now,
    super.key,
  });

  final CaptureInputMode inputMode;
  final bool attachMode;
  final VoidCallback onStartVoice;
  final ValueChanged<String> onSaveTyped;
  final ValueChanged<CaptureInputMode> onSwitchMode;
  final bool permissionBlocked;
  final bool permissionRequiresSettings;
  final bool microphoneGranted;
  final String? errorMessage;
  final TextEditingController typedController;
  final bool saving;
  final RoutineJournalPrompt? routinePrompt;
  final bool routinePromptLoading;
  final ValueChanged<String>? onSelectRoutinePrompt;
  final VoidCallback? onDismissRoutinePrompt;

  /// Selects a starter line without leaving voice capture.
  final ValueChanged<String>? onPromptContext;

  /// Clock for the date line. Defaults to [DateTime.now].
  final DateTime? now;

  bool get _showsPermissionCopy =>
      MicrophonePermissionCopy.showsPermissionExplanation(
        granted: microphoneGranted,
        blocked: permissionBlocked,
        requiresSettings: permissionRequiresSettings,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 667.0;
        return SingleChildScrollView(
          key: const Key('capture_ready_scroll'),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport),
            child: inputMode == CaptureInputMode.typed || attachMode
                ? _typedLayout(context, viewport)
                : _voiceLayout(context, viewport),
          ),
        );
      },
    );
  }

  Widget _voiceLayout(BuildContext context, double viewport) {
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: context.palette.textSecondary, height: 1.45);
    final muted = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: context.palette.textMuted, fontSize: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          captureDateLine(now ?? DateTime.now()),
          key: const Key('capture_date_line'),
          style: muted,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!attachMode)
          _PromptChip(
            onSelected: (line) {
              onPromptContext?.call(line);
            },
          ),
        if (_showsPermissionCopy) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            MicrophonePermissionCopy.neededTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(MicrophonePermissionCopy.neededBody, style: bodyStyle),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: saving ? null : onStartVoice,
            child: const Text(MicrophonePermissionCopy.requestMicrophoneCta),
          ),
        ],
        if (errorMessage != null && errorMessage!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            errorMessage!,
            style: bodyStyle.copyWith(color: context.palette.error),
          ),
        ],
        if (permissionRequiresSettings) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(MicrophonePermissionCopy.statusBlocked, style: bodyStyle),
        ] else if (permissionBlocked) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            MicrophonePermissionCopy.typeInsteadBlockedHelper,
            style: bodyStyle,
          ),
        ],
        SizedBox(height: viewport * 0.28),
        Center(
          child: KeyedSubtree(
            key: const Key('capture_start_voice'),
            child: Semantics(
              button: true,
              label: MicrophonePermissionCopy.startRecordingLabel,
              child: Material(
                key: const Key('capture_record_button'),
                color: context.palette.accentPrimary,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: saving ? null : onStartVoice,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 96,
                    height: 96,
                    child: Icon(Icons.mic, color: Colors.white, size: 36),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!attachMode) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            key: const Key('capture_type_instead'),
            onPressed: saving
                ? null
                : () => onSwitchMode(CaptureInputMode.typed),
            child: Text(MicrophonePermissionCopy.typeInsteadCta),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          MicrophonePermissionCopy.savedOnDevice,
          textAlign: TextAlign.center,
          style: muted,
        ),
      ],
    );
  }

  Widget _typedLayout(BuildContext context, double viewport) {
    final hint = routinePrompt?.primaryPrompt.trim().isNotEmpty == true
        ? routinePrompt!.primaryPrompt
        : QuickTextCaptureCopy.focusedPlaceholder;
    final fieldHeight = viewport * 0.62;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: fieldHeight < 120 ? 120 : fieldHeight,
          child: TextField(
            key: const Key('capture_typed_field'),
            controller: typedController,
            autofocus: true,
            expands: true,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          key: const Key('capture_save_typed'),
          onPressed: saving
              ? null
              : () => onSaveTyped(typedController.text.trim()),
          child: const Text(MicrophonePermissionCopy.saveTypedCta),
        ),
        if (!attachMode)
          TextButton(
            key: const Key('capture_back_to_voice'),
            onPressed: saving
                ? null
                : () => onSwitchMode(CaptureInputMode.voice),
            child: const Text(MicrophonePermissionCopy.backToVoiceCta),
          ),
      ],
    );
  }
}

String captureDateLine(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}

class _PromptChip extends StatefulWidget {
  const _PromptChip({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  State<_PromptChip> createState() => _PromptChipState();
}

class _PromptChipState extends State<_PromptChip> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final prompts = ExamplePromptCatalog.prompts;
    if (prompts.isEmpty) return const SizedBox.shrink();
    final line = prompts[_index % prompts.length];
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Flexible(
            child: ActionChip(
              key: const Key('capture_prompt_chip'),
              label: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis),
              onPressed: () => widget.onSelected(line),
            ),
          ),
          IconButton(
            key: const Key('capture_prompt_refresh'),
            tooltip: 'Another prompt',
            onPressed: () => setState(() => _index++),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
                'Your entry is recorded on this device.',
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
