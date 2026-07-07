import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/correction_memory/correction_memory_analytics.dart';
import '../../features/correction_memory/correction_memory_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Surfaces a saved archive correction — no transcript text, no Pro CTA.
class CorrectionMemoryCard extends StatefulWidget {
  const CorrectionMemoryCard({
    super.key,
    required this.result,
    required this.source,
  });

  const CorrectionMemoryCard.test({
    super.key,
    required this.result,
    required this.source,
  });

  final CorrectionMemoryResult result;
  final String source;

  @override
  State<CorrectionMemoryCard> createState() => _CorrectionMemoryCardState();
}

class _CorrectionMemoryCardState extends State<CorrectionMemoryCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    CorrectionMemoryAnalytics.seen(
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
      key: const Key('correction_memory_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAF8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('correction_memory_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: Key('correction_memory_body_${widget.result.state.name}'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.footer,
            key: const Key('correction_memory_footer'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.differentiationLine,
            key: const Key('correction_memory_differentiation_line'),
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
