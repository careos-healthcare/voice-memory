import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Zero-entry Patterns preview — product promise, not a conclusion.
class PatternsEmptyArchivePreviewCard extends StatelessWidget {
  const PatternsEmptyArchivePreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('patterns_empty_archive_preview_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9F4),
        borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: VoiceMemoryCards.standard().boxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            VisibleArchiveProofCopy.patternsEmptyPreviewBadge,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            VisibleArchiveProofCopy.patternsEmptyPreviewTitle,
            style: ArchiveMobileTypography.responsivePageTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            VisibleArchiveProofCopy.patternsEmptyPreviewBody,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.md),
          _PreviewRow(
            label: 'Current belief',
            value: VisibleArchiveProofCopy.patternsEmptyPreviewBeliefRow,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PreviewRow(
            label: 'Evidence',
            value: VisibleArchiveProofCopy.patternsEmptyPreviewEvidenceRow,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PreviewRow(
            label: 'What changed',
            value: VisibleArchiveProofCopy.patternsEmptyPreviewChangedRow,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () => context.go('/record'),
            child: Text(VisibleArchiveProofCopy.patternsEmptyPreviewCta),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: ArchiveMobileTypography.body(context),
        ),
      ],
    );
  }
}
