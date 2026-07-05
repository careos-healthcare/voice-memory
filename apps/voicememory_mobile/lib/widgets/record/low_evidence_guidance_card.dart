import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/low_evidence/low_evidence_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact reassurance when the archive is still collecting evidence.
class LowEvidenceGuidanceCard extends StatelessWidget {
  const LowEvidenceGuidanceCard({
    super.key,
    required this.guidance,
  });

  final LowEvidenceGuidance guidance;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('low_evidence_guidance_card_${guidance.kind.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            guidance.title,
            key: const Key('low_evidence_guidance_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            guidance.body,
            key: const Key('low_evidence_guidance_body'),
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
