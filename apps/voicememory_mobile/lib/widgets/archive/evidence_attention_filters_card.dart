import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/evidence_attention_filters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact local filter chips for archive evidence needing attention.
class EvidenceAttentionFiltersCard extends StatelessWidget {
  const EvidenceAttentionFiltersCard({
    super.key,
    required this.filters,
    this.onFilterTap,
  });

  final EvidenceAttentionFilters filters;
  final ValueChanged<EvidenceAttentionFilter>? onFilterTap;

  @override
  Widget build(BuildContext context) {
    if (!filters.showCard) return const SizedBox.shrink();

    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);

    return Container(
      key: const Key('evidence_attention_filters_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            filters.title,
            key: const Key('evidence_attention_filters_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final filter in filters.filters)
                FilterChip(
                  key: Key('evidence_attention_filter_${filter.kind.name}'),
                  label: Text(filter.label),
                  onSelected: onFilterTap == null
                      ? null
                      : (_) => onFilterTap!(filter),
                  selected: false,
                  showCheckmark: false,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
