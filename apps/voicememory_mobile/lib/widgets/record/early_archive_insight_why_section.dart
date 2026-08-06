import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/early_archive_insight_why_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Collapsed-by-default evidence reasons behind an early archive insight.
class EarlyArchiveInsightWhySection extends StatefulWidget {
  const EarlyArchiveInsightWhySection({
    super.key,
    required this.reasons,
    this.insightKey = 'default',
  });

  final List<String> reasons;
  final String insightKey;

  @override
  State<EarlyArchiveInsightWhySection> createState() =>
      _EarlyArchiveInsightWhySectionState();
}

class _EarlyArchiveInsightWhySectionState
    extends State<EarlyArchiveInsightWhySection> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.reasons.isEmpty) return const SizedBox.shrink();

    final helperStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontSize: 12, height: 1.4);
    final reasonStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, fontSize: 13, height: 1.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: Key('early_archive_insight_why_link_${widget.insightKey}'),
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              EarlyArchiveInsightWhyCopy.linkLabel,
              style: helperStyle.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textSecondary.withValues(
                  alpha: 0.45,
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < widget.reasons.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                widget.reasons[i],
                key: Key(
                  'early_archive_insight_why_reason_${widget.insightKey}_$i',
                ),
                style: reasonStyle,
              ),
            ),
        ],
      ],
    );
  }
}
