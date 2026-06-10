import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pressure_retention/pressure_personal_evidence_summary_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact "why this may be your pattern" card — grounds the pattern in the
/// user's own repeated terms so it reads personal, not generic.
class PressurePersonalEvidenceSummaryCard extends StatelessWidget {
  const PressurePersonalEvidenceSummaryCard({super.key, required this.summary});

  final PressurePersonalEvidenceSummary summary;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasSummary) return const SizedBox.shrink();

    return Container(
      key: const Key('pressure_personal_evidence_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF1F6F3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fingerprint_outlined,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  PressurePersonalEvidenceSummary.headline,
                  style:
                      ArchiveMobileTypography.responsiveSectionTitle(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (summary.reasonLine != null)
            Text(
              summary.reasonLine!,
              style: ArchiveMobileTypography.body(context).copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          if (summary.evidenceTerms.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final term in summary.evidenceTerms)
                  _evidenceChip(context, term),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (summary.confidenceLabel != null)
                _confidencePill(context, summary.confidenceLabel!),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  '${summary.entryCount} pressure moments so far',
                  style: ArchiveMobileTypography.responsiveHelper(context)
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _evidenceChip(BuildContext context, String label) {
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

  Widget _confidencePill(BuildContext context, String label) {
    return Container(
      key: const Key('pressure_personal_evidence_confidence'),
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
}
