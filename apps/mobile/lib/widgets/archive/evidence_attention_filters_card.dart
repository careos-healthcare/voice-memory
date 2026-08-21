import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/activation/evidence_attention_filters.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Compact local filter chips for archive evidence needing attention.
class EvidenceAttentionFiltersCard extends StatelessWidget {
  const EvidenceAttentionFiltersCard({
    required this.filters, super.key,
    this.onFilterTap,
    this.hideTitle = false,
  });

  final EvidenceAttentionFilters filters;
  final ValueChanged<EvidenceAttentionFilter>? onFilterTap;
  final bool hideTitle;

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
          if (!hideTitle) ...[
            Text(
              filters.title,
              key: const Key('evidence_attention_filters_title'),
              style: titleStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
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
                  showCheckmark: false,
                ),
            ],
          ),
        ],
      ),
    );
  }
}