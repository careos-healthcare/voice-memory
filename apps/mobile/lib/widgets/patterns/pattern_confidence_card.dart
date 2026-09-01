import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pattern_confidence/pattern_confidence_analytics.dart';
import 'package:archiveme_mobile/features/pattern_confidence/pattern_confidence_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// Explains why ArchiveMe shows a pattern — human labels only, no Pro CTA.
class PatternConfidenceCard extends StatefulWidget {
  const PatternConfidenceCard({
    required this.result,
    required this.source,
    super.key,
    this.compact = false,
    this.onViewEvidence,
  });

  const PatternConfidenceCard.test({
    required this.result,
    required this.source,
    super.key,
    this.compact = false,
    this.onViewEvidence,
  });

  final PatternConfidenceExplanationResult result;
  final String source;
  final bool compact;
  final VoidCallback? onViewEvidence;

  @override
  State<PatternConfidenceCard> createState() => _PatternConfidenceCardState();
}

class _PatternConfidenceCardState extends State<PatternConfidenceCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    PatternConfidenceAnalytics.seen(
      source: widget.source,
      result: widget.result,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600);

    return Container(
      key: const Key('pattern_confidence_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('pattern_confidence_title'),
            style: widget.compact
                ? labelStyle
                : ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          if (!widget.compact) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.result.intro,
              key: const Key('pattern_confidence_intro'),
              style: bodyStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                widget.result.label,
                key: Key(
                  'pattern_confidence_label_${widget.result.confidenceState.name}',
                ),
                style: labelStyle,
              ),
              if (widget.onViewEvidence != null ||
                  widget.result.contributingEntryIds.isNotEmpty)
                ViewEvidenceInlineLink(
                  key: const Key('pattern_confidence_card_view_evidence'),
                  entryIds: widget.result.contributingEntryIds,
                  surface: 'pattern_confidence',
                  claimContext: widget.result.label,
                  onViewEvidence: widget.onViewEvidence,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: Key(
              'pattern_confidence_body_${widget.result.confidenceState.name}',
            ),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          if (!widget.compact) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.footer,
              key: const Key('pattern_confidence_footer'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.differentiationLine,
              key: const Key('pattern_confidence_differentiation_line'),
              style: ArchiveMobileTypography.cardLabel(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
