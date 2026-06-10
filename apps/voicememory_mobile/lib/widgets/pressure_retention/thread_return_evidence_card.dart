import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pressure_retention/thread_return_evidence_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact thread continuity card: what returned, how often, and the exact
/// recordings behind it. Renders nothing without real repeated evidence.
class ThreadReturnEvidenceCard extends StatelessWidget {
  const ThreadReturnEvidenceCard({super.key, required this.evidence});

  final ThreadReturnEvidence evidence;

  @override
  Widget build(BuildContext context) {
    if (!evidence.hasEvidence) return const SizedBox.shrink();

    return Container(
      key: const Key('thread_return_evidence_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF3F4FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline_outlined,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  evidence.headline,
                  style:
                      ArchiveMobileTypography.responsiveSectionTitle(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            evidence.summaryLine,
            style: ArchiveMobileTypography.body(context).copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _statusChip(context),
              _pill(context, evidence.confidenceLabel),
              for (final term in evidence.sourceTerms) _termChip(context, term),
            ],
          ),
          if (evidence.evidenceSnippets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ThreadReturnEvidence.evidenceHeading,
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final snippet in evidence.evidenceSnippets)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '\u201C$snippet\u201D',
                  style: ArchiveMobileTypography.responsiveHelper(context)
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            ThreadReturnEvidence.basedOnLine,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context) {
    return Container(
      key: const Key('thread_return_status_chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        evidence.statusLabel,
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _termChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
