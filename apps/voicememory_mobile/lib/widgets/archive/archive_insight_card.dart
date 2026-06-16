import 'package:flutter/material.dart';

import '../../features/insights/archive_insight.dart';
import '../../product/belief_product_copy.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../theme/voicememory_typography.dart';

/// What / Why / Evidence for a single [ArchiveInsight].
class ArchiveInsightCard extends StatelessWidget {
  const ArchiveInsightCard({super.key, required this.insight, this.onTap});

  final ArchiveInsight insight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final quote = insight.supportingEvidence
        .map((e) => e.quote.trim())
        .where((q) => q.length >= 12)
        .firstOrNull;

    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(ConsumerUiCopy.labelWhat),
        const SizedBox(height: 4),
        Text(insight.what, style: VoiceMemoryTypography.cardTitleStyle()),
        const SizedBox(height: AppSpacing.md),
        _label(BeliefProductCopy.labelWhy),
        const SizedBox(height: 4),
        Text(
          insight.why,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ),
        ),
        if (insight.archiveConclusion != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _label(ConsumerUiCopy.labelWhatThisMeans),
          const SizedBox(height: 4),
          Text(
            insight.archiveConclusion!,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _label(ConsumerUiCopy.labelMoments),
        const SizedBox(height: 4),
        Text(
          '${insight.evidenceCount} ${BeliefProductCopy.reflectionsWord} · ${insight.confidence}% ${ConsumerUiCopy.labelConfidence.toLowerCase()}',
          style: VoiceMemoryTypography.bodyStyle(),
        ),
        if (quote != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '“$quote”',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );

    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(),
      child: child,
    );

    if (onTap == null) return box;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
        child: box,
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: VoiceMemoryTypography.metadataStyle(
      color: AppColors.accentPrimary,
    ).copyWith(fontWeight: FontWeight.w600),
  );
}

extension _FirstOrNullInsight<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
