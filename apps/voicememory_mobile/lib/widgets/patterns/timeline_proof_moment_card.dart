import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/timeline_proof_moment/timeline_proof_moment_analytics.dart';
import '../../features/timeline_proof_moment/timeline_proof_moment_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Concise timeline proof summary — no Pro CTA, no transcript text.
class TimelineProofMomentCard extends StatefulWidget {
  const TimelineProofMomentCard({
    super.key,
    required this.result,
    required this.source,
  });

  const TimelineProofMomentCard.test({
    super.key,
    required this.result,
    required this.source,
  });

  final TimelineProofMomentResult result;
  final String source;

  @override
  State<TimelineProofMomentCard> createState() => _TimelineProofMomentCardState();
}

class _TimelineProofMomentCardState extends State<TimelineProofMomentCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    TimelineProofMomentAnalytics.seen(
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
    final rowStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    return Container(
      key: const Key('timeline_proof_moment_card'),
      width: double.infinity,
      padding: EdgeInsets.all(
        widget.result.compact ? AppSpacing.sm : AppSpacing.md,
      ),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAFC)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('timeline_proof_moment_title'),
            style: widget.result.compact
                ? rowStyle
                : ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          if (!widget.result.compact) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.result.body,
              key: const Key('timeline_proof_moment_body'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          for (final row in widget.result.rows) ...[
            Text(
              row.label,
              key: Key('timeline_proof_moment_row_${row.label.hashCode}'),
              style: rowStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            widget.result.currentWeightLine,
            key: Key(
              'timeline_proof_moment_weight_${widget.result.currentWeight.name}',
            ),
            style: rowStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!widget.result.compact) ...[
            Text(
              widget.result.footer,
              key: const Key('timeline_proof_moment_footer'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.differentiationLine,
              key: const Key('timeline_proof_moment_differentiation'),
              style: ArchiveMobileTypography.cardLabel(context).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            widget.result.proLine,
            key: const Key('timeline_proof_moment_pro_line'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}
