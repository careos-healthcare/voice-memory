import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/return_check_payoff_analytics.dart';
import '../../features/early_archive/return_check_payoff_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Post-save payoff comparing a related return with the first proof — no CTAs.
class ReturnCheckPayoffCard extends StatelessWidget {
  const ReturnCheckPayoffCard({
    super.key,
    required this.payoff,
    required this.entryCount,
  });

  final ReturnCheckPayoff payoff;
  final int entryCount;

  void _trackSeen() {
    ReturnCheckPayoffAnalytics.seen(
      entryCount: entryCount,
      comparisonState: payoff.state,
      hasPhrase: payoff.hasPhrase,
      hasConfirmedRepeat: payoff.hasConfirmedRepeat,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeen();
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary);

    return Container(
      key: Key('return_check_payoff_card_${payoff.state.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            payoff.evidenceLabel,
            key: const Key('return_check_payoff_evidence_label'),
            style: ArchiveMobileTypography.cardLabel(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            payoff.title,
            key: const Key('return_check_payoff_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            payoff.body,
            key: const Key('return_check_payoff_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            payoff.footer,
            key: const Key('return_check_payoff_footer'),
            style: bodyStyle.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
