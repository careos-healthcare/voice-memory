import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/prove_enough/prove_enough_post_record_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Enoughness score summary after a prove_enough recording.
class EnoughnessScoreCard extends StatelessWidget {
  const EnoughnessScoreCard({
    super.key,
    required this.model,
  });

  final ProveEnoughPostRecordModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FBFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enoughness score',
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            model.enoughnessLabel,
            style: ArchiveMobileTypography.body(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (!model.transcriptWeak) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${model.enoughnessScore}',
              style: ArchiveMobileTypography.responsiveSectionTitle(context).copyWith(
                fontSize: 36,
                color: AppColors.accentPrimary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _RowLabel(
            label: 'Pressure',
            value: model.transcriptWeak ? 'Not clear' : model.pressureLevel.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          _RowLabel(
            label: 'Choice',
            value: model.transcriptWeak ? 'Not clear' : model.choiceLevel.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          _RowLabel(
            label: 'Rest guilt',
            value: model.transcriptWeak ? 'Not clear' : model.restGuiltLabel,
          ),
        ],
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
        ),
        Text(
          value,
          style: ArchiveMobileTypography.body(context).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
