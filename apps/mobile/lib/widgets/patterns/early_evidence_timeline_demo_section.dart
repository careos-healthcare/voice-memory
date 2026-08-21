import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/early_archive/early_archive_proof_analytics.dart';
import 'package:archiveme_mobile/features/early_archive/early_evidence_timeline_demo.dart';
import 'package:archiveme_mobile/features/early_archive/early_evidence_timeline_demo_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/record/early_evidence_timeline_card.dart';
import 'package:flutter/material.dart';

/// Sample early evidence preview for zero- or one-entry Patterns states.
class EarlyEvidenceTimelineDemoCta extends StatelessWidget {
  const EarlyEvidenceTimelineDemoCta({
    required this.onTap, required this.entryCount, required this.surface, super.key,
  });

  final VoidCallback onTap;
  final int entryCount;
  final String surface;

  @override
  Widget build(BuildContext context) {
    EarlyArchiveProofAnalytics.demoCtaSeen(
      entryCount: entryCount,
      surface: surface,
    );
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: const Key('early_evidence_demo_cta'),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        child: Text(
          EarlyEvidenceTimelineDemoCopy.cta,
          style: ArchiveMobileTypography.cardLabel(
            context,
          ).copyWith(color: AppColors.accentPrimary),
        ),
      ),
    );
  }
}

class EarlyEvidenceTimelineDemoSection extends StatelessWidget {
  const EarlyEvidenceTimelineDemoSection({
    required this.onHide, required this.entryCount, required this.surface, super.key,
  });

  final VoidCallback onHide;
  final int entryCount;
  final String surface;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('early_evidence_demo_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            key: const Key('early_evidence_demo_sample_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              EarlyEvidenceTimelineDemoCopy.sampleBadge,
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 12,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const EarlyEvidenceTimelineCard(
          key: Key('early_evidence_demo_timeline_card'),
          timeline: EarlyEvidenceTimelineDemo.timeline,
          isSample: true,
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('early_evidence_demo_hide_cta'),
            onPressed: onHide,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: EdgeInsets.zero,
            ),
            child: const Text(EarlyEvidenceTimelineDemoCopy.hideSample),
          ),
        ),
      ],
    );
  }
}