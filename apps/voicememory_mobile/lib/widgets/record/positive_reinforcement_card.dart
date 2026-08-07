import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/positive_reinforcement_copy.dart';
import '../../features/early_archive/positive_reinforcement_engine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Gentle loop after a helpful action pattern — repeat, notice, record again.
class PositiveReinforcementCard extends StatelessWidget {
  const PositiveReinforcementCard({
    super.key,
    required this.reinforcement,
    required this.showRecordAgainCta,
    this.onRecordAgain,
  });

  final PositiveReinforcementResult reinforcement;
  final bool showRecordAgainCta;
  final VoidCallback? onRecordAgain;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final evidenceStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('positive_reinforcement_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAF8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            reinforcement.title,
            key: const Key('positive_reinforcement_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reinforcement.body,
            key: const Key('positive_reinforcement_body'),
            style: bodyStyle,
          ),
          if (reinforcement.evidencePhrases.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final phrase in reinforcement.evidencePhrases)
              Padding(
                key: Key('positive_reinforcement_evidence_$phrase'),
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(phrase, style: evidenceStyle),
              ),
          ],
          if (showRecordAgainCta && onRecordAgain != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('positive_reinforcement_record_cta'),
                onPressed: onRecordAgain,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(PositiveReinforcementCopy.recordAgainCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
