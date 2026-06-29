import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/early_first_signal_engine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Post-save payoff after the user captures the trigger from the return prompt.
class ConfirmedRepeatTriggerPayoffCard extends StatelessWidget {
  const ConfirmedRepeatTriggerPayoffCard({
    super.key,
    required this.payoff,
    required this.onKeepWatching,
    required this.onViewEvidence,
  });

  final ConfirmedRepeatTriggerPayoff payoff;
  final VoidCallback onKeepWatching;
  final VoidCallback onViewEvidence;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final evidenceStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.4,
    );

    return Container(
      key: const Key('confirmed_repeat_trigger_payoff_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            payoff.title,
            key: const Key('confirmed_repeat_trigger_payoff_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            payoff.body,
            key: const Key('confirmed_repeat_trigger_payoff_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final line in payoff.evidenceLines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                line,
                key: ValueKey('confirmed_repeat_trigger_payoff_evidence_$line'),
                style: evidenceStyle,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('confirmed_repeat_trigger_payoff_primary_cta'),
            onPressed: onKeepWatching,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: Colors.white,
            ),
            child: Text(payoff.primaryCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            key: const Key('confirmed_repeat_trigger_payoff_view_evidence_cta'),
            onPressed: onViewEvidence,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentPrimary,
            ),
            child: Text(payoff.secondaryCta),
          ),
        ],
      ),
    );
  }
}
