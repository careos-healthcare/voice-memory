import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/prove_enough/loop_trigger_map_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Shows what tends to trigger the prove_enough loop across saved moments.
class LoopTriggerMapCard extends StatelessWidget {
  const LoopTriggerMapCard({
    super.key,
    required this.model,
  });

  final LoopTriggerMapModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('loop_trigger_map_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FBFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Loop trigger map',
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!model.hasEnoughData)
            Text(
              LoopTriggerMapModel.notEnoughDataCopy,
              style: ArchiveMobileTypography.body(context).copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            Text(
              LoopTriggerMapModel.enoughDataHeadline,
              style: ArchiveMobileTypography.body(context).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...model.rankedRows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _TriggerRow(row: row),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TriggerRow extends StatelessWidget {
  const _TriggerRow({required this.row});

  final LoopTriggerMapRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.category.label,
                style: ArchiveMobileTypography.cardLabel(context),
              ),
            ),
            Text(
              '${row.count}',
              style: ArchiveMobileTypography.body(context).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (row.lastEvidencePhrase.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            row.lastEvidencePhrase,
            style: ArchiveMobileTypography.body(context).copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
