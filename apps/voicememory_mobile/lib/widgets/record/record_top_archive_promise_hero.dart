import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Dominant top-of-screen product promise on Record (zero entries).
class RecordTopArchivePromiseHero extends StatelessWidget {
  const RecordTopArchivePromiseHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('record_top_archive_promise_hero'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8F5),
        borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: VoiceMemoryCards.standard().boxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            VisibleArchiveProofCopy.recordHeroTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            VisibleArchiveProofCopy.recordHeroBody,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _PromiseChip(label: VisibleArchiveProofCopy.recordHeroChipReturned),
              _PromiseChip(label: VisibleArchiveProofCopy.recordHeroChipSoftened),
              _PromiseChip(label: VisibleArchiveProofCopy.recordHeroChipChanged),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromiseChip extends StatelessWidget {
  const _PromiseChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.accentPrimary,
        ),
      ),
    );
  }
}
