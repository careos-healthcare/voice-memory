import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/voice_capture/analysis_fallback_payoff.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Local archive payoff when transcription succeeded but analysis is offline.
class AnalysisFallbackPayoffCard extends StatelessWidget {
  const AnalysisFallbackPayoffCard({required this.payoff, super.key});

  final AnalysisFallbackPayoff payoff;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);
    final footnoteStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

    return Container(
      key: const Key('analysis_fallback_payoff_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            payoff.title,
            key: const Key('analysis_fallback_payoff_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            payoff.body,
            key: const Key('analysis_fallback_payoff_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            payoff.evidenceLine,
            key: const Key('analysis_fallback_payoff_evidence'),
            style: bodyStyle,
          ),
          if (payoff.secondaryLine case final secondary?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              secondary,
              key: const Key('analysis_fallback_payoff_secondary'),
              style: bodyStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text('Next:', style: labelStyle),
          const SizedBox(height: 4),
          Text(
            payoff.nextActionLine,
            key: const Key('analysis_fallback_payoff_next_action'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            payoff.footnoteLine,
            key: const Key('analysis_fallback_payoff_footnote'),
            style: footnoteStyle,
          ),
        ],
      ),
    );
  }
}