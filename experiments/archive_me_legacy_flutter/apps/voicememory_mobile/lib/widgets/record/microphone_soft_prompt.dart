import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/voice_capture/microphone_permission_copy.dart';
import '../../theme/app_spacing.dart';

class MicrophoneSoftPrompt extends StatelessWidget {
  const MicrophoneSoftPrompt({
    super.key,
    required this.onContinue,
    required this.onNotNow,
  });

  final VoidCallback onContinue;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      namesRoute: true,
      label: MicrophonePermissionCopy.softPromptTitle,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          key: const Key('microphone_soft_prompt'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mic_none, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(
              MicrophonePermissionCopy.softPromptTitle,
              textAlign: TextAlign.center,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              MicrophonePermissionCopy.softPromptBody,
              textAlign: TextAlign.center,
              style: ArchiveMobileTypography.responsiveBody(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              MicrophonePermissionCopy.softPromptPrivacy,
              key: const Key('microphone_soft_prompt_privacy'),
              textAlign: TextAlign.center,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('microphone_soft_prompt_continue'),
              onPressed: onContinue,
              child: const Text(MicrophonePermissionCopy.requestMicrophoneCta),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('microphone_soft_prompt_not_now'),
              onPressed: onNotNow,
              child: const Text(MicrophonePermissionCopy.notNowCta),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showMicrophoneSoftPrompt(BuildContext context) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isDismissible: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => MicrophoneSoftPrompt(
          onContinue: () => Navigator.of(context).pop(true),
          onNotNow: () => Navigator.of(context).pop(false),
        ),
      ) ??
      false;
}
