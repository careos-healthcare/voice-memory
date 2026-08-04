import 'package:flutter/material.dart';

import 'domain/application/interpretation_disposition_coordinator.dart';
import 'domain/application/post_capture_disposition_coordinator.dart';

const _dispositionKeys = <PostCaptureDisposition, Key>{
  PostCaptureDisposition.transcribeOnDevice: Key(
    'post_capture_choice_on_device',
  ),
  PostCaptureDisposition.transcribeOnline: Key('post_capture_choice_online'),
  PostCaptureDisposition.saveAudioOnly: Key('post_capture_choice_audio_only'),
  PostCaptureDisposition.deleteRecording: Key('post_capture_choice_delete'),
};

const _interpretationKeys = <InterpretationDisposition, Key>{
  InterpretationDisposition.generatePossibleRead: Key(
    'post_capture_interpretation_generate',
  ),
  InterpretationDisposition.saveWithoutInterpretation: Key(
    'post_capture_interpretation_decline',
  ),
};

String _detailFor(PostCaptureDisposition disposition) => switch (disposition) {
  PostCaptureDisposition.transcribeOnDevice => PostCaptureCopy.onDeviceDetail,
  PostCaptureDisposition.transcribeOnline => PostCaptureCopy.onlineDetail,
  PostCaptureDisposition.saveAudioOnly => PostCaptureCopy.saveAudioOnlyDetail,
  PostCaptureDisposition.deleteRecording => PostCaptureCopy.deleteDetail,
};

/// Asks how an already-vaulted recording should be handled.
///
/// Every option is rendered identically: no badge, no default selection, and
/// no emphasis on the option that sends audio away. Dismissing the sheet
/// returns null, which the coordinator treats as keeping the audio.
Future<PostCaptureDisposition?> showPostCaptureChoiceSheet({
  required BuildContext context,
  required PostCaptureChoiceOptions options,
}) {
  return showModalBottomSheet<PostCaptureDisposition>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          key: const Key('post_capture_choice_sheet'),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(PostCaptureCopy.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(PostCaptureCopy.body, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              for (final disposition in options.available)
                _ChoiceTile(
                  tileKey: _dispositionKeys[disposition]!,
                  title: disposition.label,
                  detail: _detailFor(disposition),
                  destructive:
                      disposition == PostCaptureDisposition.deleteRecording,
                  onSelected: () => Navigator.of(sheetContext).pop(disposition),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Asks whether the saved moment may be interpreted.
///
/// Shown after the recording is already committed, so dismissing it is a
/// complete answer: null means no interpretation.
Future<InterpretationDisposition?> showInterpretationChoiceSheet({
  required BuildContext context,
}) {
  return showModalBottomSheet<InterpretationDisposition>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          key: const Key('post_capture_interpretation_sheet'),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(InterpretationCopy.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(InterpretationCopy.body, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              for (final disposition in InterpretationDisposition.values)
                _ChoiceTile(
                  tileKey: _interpretationKeys[disposition]!,
                  title: disposition.label,
                  detail: disposition.detail,
                  destructive: false,
                  onSelected: () => Navigator.of(sheetContext).pop(disposition),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Explicit second step before any audio is destroyed.
Future<bool> showPostCaptureDeleteConfirmation({
  required BuildContext context,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      key: const Key('post_capture_delete_confirmation'),
      title: const Text(PostCaptureCopy.deleteConfirmationTitle),
      content: const Text(PostCaptureCopy.deleteConfirmationBody),
      actions: [
        TextButton(
          key: const Key('post_capture_delete_cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(PostCaptureCopy.keepCta),
        ),
        FilledButton(
          key: const Key('post_capture_delete_confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(PostCaptureCopy.deleteConfirmationCta),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

final class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.tileKey,
    required this.title,
    required this.detail,
    required this.destructive,
    required this.onSelected,
  });

  final Key tileKey;
  final String title;
  final String detail;

  /// Only ever true for permanent deletion, which is a safety signal rather
  /// than a preference between the remaining options.
  final bool destructive;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: tileKey,
        contentPadding: EdgeInsets.zero,
        onTap: onSelected,
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: destructive ? theme.colorScheme.error : null,
          ),
        ),
        subtitle: Text(detail),
      ),
    );
  }
}
