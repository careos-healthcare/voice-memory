import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_proof/archive_demo_preview_copy.dart';
import '../../features/archive_proof/archive_demo_preview_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Cold-start preview — watch state after first recording, not a conclusion.
class ArchiveDemoPreviewCard extends StatelessWidget {
  const ArchiveDemoPreviewCard({
    super.key,
    required this.preview,
    this.onRecordNext,
  });

  final ArchiveDemoPreview preview;
  final VoidCallback? onRecordNext;

  @override
  Widget build(BuildContext context) {
    if (!preview.shouldShow) return const SizedBox.shrink();

    return Container(
      key: const Key('archive_demo_preview_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ArchiveDemoPreviewCopy.previewBadge,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveDemoPreviewCopy.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.md),
          _row(
            context,
            label: ArchiveDemoPreviewCopy.patternFirstSeenLabel,
            body: preview.patternFirstSeen,
            bodyKey: const Key('archive_demo_preview_pattern'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(
            context,
            label: ArchiveDemoPreviewCopy.repeatWouldBeLabel,
            body: preview.repeatWouldBe,
            bodyKey: const Key('archive_demo_preview_repeat'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(
            context,
            label: ArchiveDemoPreviewCopy.softeningWouldBeLabel,
            body: preview.softeningWouldBe,
            bodyKey: const Key('archive_demo_preview_softening'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(
            context,
            label: ArchiveDemoPreviewCopy.recordNextLabel,
            body: preview.recordNext,
            bodyKey: const Key('archive_demo_preview_record_next'),
          ),
          if (onRecordNext != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('archive_demo_preview_record_cta'),
                onPressed: onRecordNext,
                child: const Text('Record this next'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required String body,
    Key? bodyKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ArchiveMobileTypography.cardLabel(context).copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          key: bodyKey,
          style: ArchiveMobileTypography.body(context),
        ),
      ],
    );
  }
}
