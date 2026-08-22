import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Compact pending-transcript recovery prompt with optional action.
class PendingTranscriptRecoveryPrompt extends StatelessWidget {
  const PendingTranscriptRecoveryPrompt({
    super.key,
    this.onAddWhatYouSaid,
    this.showHelper = true,
    this.compact = false,
  });

  final VoidCallback? onAddWhatYouSaid;
  final bool showHelper;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = compact
        ? ArchiveMobileTypography.responsiveSectionTitle(context)
        : ArchiveMobileTypography.responsivePageTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context);

    return Column(
      key: const Key('pending_transcript_recovery_prompt'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          PendingTranscriptRecoveryCopy.title,
          key: const Key('pending_transcript_recovery_title'),
          style: titleStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          PendingTranscriptRecoveryCopy.body,
          key: const Key('pending_transcript_recovery_body'),
          style: bodyStyle,
        ),
        if (showHelper) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            PendingTranscriptRecoveryCopy.helper,
            key: const Key('pending_transcript_recovery_helper'),
            style: bodyStyle.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (onAddWhatYouSaid != null) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('pending_transcript_recovery_add_what_you_said'),
            onPressed: onAddWhatYouSaid,
            child: const Text(PendingTranscriptRecoveryCopy.primaryAction),
          ),
        ],
      ],
    );
  }
}