import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/onboarding/first_proof_journey_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Early Record journey strip — save, compare, first thread. No daily streak framing.
class FirstProofJourneyStripCard extends StatelessWidget {
  const FirstProofJourneyStripCard({super.key});

  @override
  Widget build(BuildContext context) {
    final stripStyle = ArchiveMobileTypography.responsiveHelper(context)
        .copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.textPrimary,
        );
    final helperStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontSize: 12, height: 1.35);

    return Container(
      key: const Key('first_proof_journey_strip_card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            FirstProofJourneyCopy.strip,
            key: const Key('first_proof_journey_strip'),
            style: stripStyle,
          ),
          const SizedBox(height: 2),
          Text(
            FirstProofJourneyCopy.helper,
            key: const Key('first_proof_journey_helper'),
            style: helperStyle,
          ),
        ],
      ),
    );
  }
}