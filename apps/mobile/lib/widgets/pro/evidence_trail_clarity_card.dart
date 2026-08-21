import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/evidence_trail_clarity/evidence_trail_clarity_analytics.dart';
import 'package:archiveme_mobile/features/evidence_trail_clarity/evidence_trail_clarity_copy.dart';
import 'package:archiveme_mobile/features/evidence_trail_clarity/evidence_trail_clarity_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

class EvidenceTrailClarityCard extends StatefulWidget {
  const EvidenceTrailClarityCard({
    required this.result, required this.onSeePro, super.key,
    this.compact = false,
  });

  const EvidenceTrailClarityCard.test({
    required this.result, required this.onSeePro, super.key,
    this.compact = false,
  });

  final EvidenceTrailClarityResult result;
  final VoidCallback onSeePro;
  final bool compact;

  @override
  State<EvidenceTrailClarityCard> createState() =>
      _EvidenceTrailClarityCardState();
}

class _EvidenceTrailClarityCardState extends State<EvidenceTrailClarityCard> {
  var _trackedSeen = false;
  var _dismissed = false;
  EvidenceTrailClarityFeedbackOption? _feedback;

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow || _dismissed) return;
    _trackedSeen = true;
    EvidenceTrailClarityAnalytics.seen(result: widget.result);
  }

  void _selectFeedback(EvidenceTrailClarityFeedbackOption feedback) {
    EvidenceTrailClarityAnalytics.feedbackSelected(
      result: widget.result,
      feedback: feedback,
    );
    setState(() => _feedback = feedback);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !widget.result.shouldShow) {
      return const SizedBox.shrink(
        key: Key('evidence_trail_clarity_card_hidden'),
      );
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final rowLabelStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600);
    final promptStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);

    return Container(
      key: const Key('evidence_trail_clarity_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('evidence_trail_clarity_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.sm),
          Text(
            widget.result.body,
            key: const Key('evidence_trail_clarity_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in widget.result.timelineRows) ...[
            Row(
              key: Key('evidence_trail_clarity_row_${row.label}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: Text(row.label, style: rowLabelStyle),
                ),
                Expanded(
                  child: Text(
                    row.detail,
                    style: bodyStyle.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            widget.result.supportLine,
            key: const Key('evidence_trail_clarity_support'),
            style: bodyStyle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_feedback == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.feedbackPrompt,
              key: const Key('evidence_trail_clarity_feedback_prompt'),
              style: promptStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final option in EvidenceTrailClarityCopy.feedbackOptions)
                  TextButton(
                    key: Key(
                      'evidence_trail_clarity_feedback_${option.analyticsValue}',
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () => _selectFeedback(option),
                    child: Text(EvidenceTrailClarityCopy.feedbackLabel(option)),
                  ),
              ],
            ),
          ],
          SizedBox(height: widget.compact ? AppSpacing.sm : AppSpacing.md),
          FilledButton(
            key: const Key('evidence_trail_clarity_primary_cta'),
            onPressed: () {
              EvidenceTrailClarityAnalytics.ctaTapped(result: widget.result);
              widget.onSeePro();
            },
            child: Text(widget.result.primaryCta),
          ),
          TextButton(
            key: const Key('evidence_trail_clarity_secondary_cta'),
            onPressed: () => setState(() => _dismissed = true),
            child: Text(widget.result.secondaryCta),
          ),
        ],
      ),
    );
  }
}