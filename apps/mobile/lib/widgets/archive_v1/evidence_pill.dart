import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_v1/insight_feed_copy.dart';
import 'package:flutter/material.dart';

/// Prominent tappable pill summarizing ledger citation count.
class EvidencePill extends StatelessWidget {
  const EvidencePill({
    required this.quoteCount, required this.expanded, required this.onTap, super.key,
  });

  final int quoteCount;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = quoteCount > 0
        ? InsightFeedCopy.evidencePillLabel(quoteCount)
        : InsightFeedCopy.evidencePillEmpty;

    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      child: Material(
        color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: const Key('evidence_pill'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.fact_check_outlined,
                  size: 18,
                  color: VoiceMemoryColors.primaryIndigo,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: VoiceMemoryTypography.bodyStyle(
                      color: VoiceMemoryColors.primaryIndigo,
                    ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}