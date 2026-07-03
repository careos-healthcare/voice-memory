import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/helpful_action_appeared_analytics.dart';
import '../../features/early_archive/helpful_action_appeared_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../proof/proof_surface_why_appeared_disclosure.dart';
import '../../features/archive_proof/proof_surface_why_appeared_copy.dart';

/// Patterns / Archive positive payoff — evidence from the user's words, no CTAs.
class HelpfulActionAppearedCard extends StatelessWidget {
  const HelpfulActionAppearedCard({
    super.key,
    required this.result,
    required this.entryCount,
    required this.source,
  });

  final HelpfulActionAppeared result;
  final int entryCount;
  final String source;

  void _trackSeen() {
    HelpfulActionAppearedAnalytics.seen(
      entryCount: entryCount,
      source: source,
      hasActionPhrase: result.usesActionPhrase,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeen();
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final labelStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textSecondary,
    );
    final chipStyle = labelStyle.copyWith(
      color: AppColors.accentPrimary,
    );

    return Container(
      key: const Key('helpful_action_appeared_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF5FAF6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.title,
                  key: const Key('helpful_action_appeared_title'),
                  style: ArchiveMobileTypography.responsiveSectionTitle(context),
                ),
              ),
              Container(
                key: const Key('helpful_action_appeared_chip'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(result.chipLabel, style: chipStyle),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.body,
            key: const Key('helpful_action_appeared_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.evidenceLabel,
            key: const Key('helpful_action_appeared_evidence_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.footer,
            key: const Key('helpful_action_appeared_footer'),
            style: bodyStyle.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          ProofSurfaceWhyAppearedDisclosure(
            body: ProofSurfaceWhyAppearedCopy.helpfulAction,
            surfaceKey: 'helpful_action_appeared',
          ),
        ],
      ),
    );
  }
}
