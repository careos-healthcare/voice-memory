import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pattern_confidence/pattern_confidence_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Compact evidence-strength chip — label only or label + helper body.
class PatternConfidenceBadge extends StatelessWidget {
  const PatternConfidenceBadge({
    super.key,
    required this.confidence,
    this.showBody = false,
    this.compact = true,
  });

  final PatternConfidence confidence;
  final bool showBody;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!confidence.shouldShow) return const SizedBox.shrink();

    final chipStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      fontSize: compact ? 12 : 13,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, fontSize: 12, height: 1.35);

    return Column(
      key: Key('pattern_confidence_badge_${confidence.state.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: Key('pattern_confidence_chip_${confidence.state.name}'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.accentPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.accentPrimary.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            confidence.label,
            key: Key('pattern_confidence_label_${confidence.state.name}'),
            style: chipStyle,
          ),
        ),
        if (showBody) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            confidence.body,
            key: Key('pattern_confidence_body_${confidence.state.name}'),
            style: bodyStyle,
          ),
        ],
      ],
    );
  }
}
