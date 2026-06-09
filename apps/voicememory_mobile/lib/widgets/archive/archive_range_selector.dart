import 'package:flutter/material.dart';

import '../../features/archive_review/archive_range_review_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Preset chips for choosing an archive review period.
class ArchiveRangeSelector extends StatelessWidget {
  const ArchiveRangeSelector({
    super.key,
    required this.selected,
    required this.onPresetSelected,
    this.enabledPresets = const [
      ArchiveReviewRangePreset.thisWeek,
      ArchiveReviewRangePreset.lastWeek,
      ArchiveReviewRangePreset.thisMonth,
      ArchiveReviewRangePreset.last30Days,
    ],
  });

  final ArchiveReviewRangePreset selected;
  final void Function(ArchiveReviewRangePreset preset) onPresetSelected;
  final List<ArchiveReviewRangePreset> enabledPresets;

  static const _labels = {
    ArchiveReviewRangePreset.thisWeek: 'This week',
    ArchiveReviewRangePreset.lastWeek: 'Last week',
    ArchiveReviewRangePreset.thisMonth: 'This month',
    ArchiveReviewRangePreset.last30Days: 'Last 30 days',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final preset in enabledPresets)
          ChoiceChip(
            label: Text(_labels[preset] ?? preset.name),
            selected: selected == preset,
            onSelected: (_) => onPresetSelected(preset),
          ),
      ],
    );
  }
}
