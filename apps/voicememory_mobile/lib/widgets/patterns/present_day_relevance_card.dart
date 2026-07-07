import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/present_day_relevance/present_day_relevance_analytics.dart';
import '../../features/present_day_relevance/present_day_relevance_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Explains why past evidence may matter now — no Pro CTA, no transcript text.
class PresentDayRelevanceCard extends StatefulWidget {
  const PresentDayRelevanceCard({
    super.key,
    required this.result,
    required this.source,
  });

  const PresentDayRelevanceCard.test({
    super.key,
    required this.result,
    required this.source,
  });

  final PresentDayRelevanceResult result;
  final String source;

  @override
  State<PresentDayRelevanceCard> createState() =>
      _PresentDayRelevanceCardState();
}

class _PresentDayRelevanceCardState extends State<PresentDayRelevanceCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    PresentDayRelevanceAnalytics.seen(
      source: widget.source,
      result: widget.result,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('present_day_relevance_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAFC)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('present_day_relevance_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('present_day_relevance_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.stateBody,
            key: Key(
              'present_day_relevance_state_${widget.result.relevanceState.name}',
            ),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.footer,
            key: const Key('present_day_relevance_footer'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.differentiationLine,
            key: const Key('present_day_relevance_differentiation_line'),
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
