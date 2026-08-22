import 'package:archiveme_mobile/features/voice_capture/transcription/local_transcription_unavailable_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// The one-time choice offered when this device cannot produce a transcript.
///
/// Both buttons record a standing answer, so neither is a dismissal. The card
/// sits above the save receipt: the recording is already saved with its audio
/// by the time this appears, and choosing [LocalTranscriptionUnavailableCopy
/// .declineCta] leaves it exactly as it is.
class LocalTranscriptionUnavailableCard extends StatelessWidget {
  const LocalTranscriptionUnavailableCard({
    required this.onChoice,
    super.key,
    this.submitting = false,
  });

  /// True for remote transcription, false for saving without text.
  final ValueChanged<bool> onChoice;
  final bool submitting;

  static const _buttonStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('local_transcription_unavailable_card'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              LocalTranscriptionUnavailableCopy.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const _Body(LocalTranscriptionUnavailableCopy.body),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('local_transcription_choose_remote'),
            style: _buttonStyle,
            onPressed: submitting ? null : () => onChoice(true),
            child: const Text(LocalTranscriptionUnavailableCopy.remoteCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          const _Body(LocalTranscriptionUnavailableCopy.remoteDetail),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('local_transcription_choose_none'),
            style: _buttonStyle,
            onPressed: submitting ? null : () => onChoice(false),
            child: const Text(LocalTranscriptionUnavailableCopy.declineCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          const _Body(LocalTranscriptionUnavailableCopy.declineDetail),
          const SizedBox(height: AppSpacing.sm),
          const _Body(LocalTranscriptionUnavailableCopy.footnote),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}
