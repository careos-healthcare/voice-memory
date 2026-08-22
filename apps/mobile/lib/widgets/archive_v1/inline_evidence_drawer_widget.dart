import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_v1/evidence_keyword_highlighter.dart';
import 'package:archiveme_mobile/widgets/archive_v1/inline_evidence_quote.dart';
import 'package:archiveme_mobile/widgets/archive_v1/insight_evidence_feedback_bar.dart';
import 'package:archiveme_mobile/widgets/archive_v1/insight_feed_copy.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Expanding in-card drawer for timestamped fact-ledger quotes.
class InlineEvidenceDrawerWidget extends StatelessWidget {
  const InlineEvidenceDrawerWidget({
    required this.quotes, required this.highlightTerms, super.key,
    this.onAgree,
    this.onDisagree,
    this.onCorrect,
    this.feedbackBusy = false,
  });

  final List<InlineEvidenceQuote> quotes;
  final List<String> highlightTerms;
  final VoidCallback? onAgree;
  final VoidCallback? onDisagree;
  final VoidCallback? onCorrect;
  final bool feedbackBusy;

  static final _timeFormat = DateFormat('EEE, MMM d · h:mm a');

  @override
  Widget build(BuildContext context) {
    final baseStyle = VoiceMemoryTypography.bodyStyle().copyWith(height: 1.45);
    final highlightStyle = baseStyle.copyWith(
      color: VoiceMemoryColors.primaryIndigo,
      fontWeight: FontWeight.w700,
      backgroundColor: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.1),
    );

    return AnimatedSize(
      key: const Key('inline_evidence_drawer'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VoiceMemoryColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (quotes.isEmpty)
              Text(
                InsightFeedCopy.drawerEmptyBody,
                style: VoiceMemoryTypography.secondaryStyle(),
              )
            else
              for (var i = 0; i < quotes.length; i++)
                _QuoteTile(
                  quote: quotes[i],
                  showDivider: i < quotes.length - 1,
                  baseStyle: baseStyle,
                  highlightStyle: highlightStyle,
                  highlightTerms: highlightTerms,
                ),
            if (onAgree != null || onDisagree != null || onCorrect != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Divider(color: VoiceMemoryColors.border.withValues(alpha: 0.8)),
              const SizedBox(height: AppSpacing.xs),
              InsightEvidenceFeedbackBar(
                onAgree: onAgree,
                onDisagree: onDisagree,
                onCorrect: onCorrect,
                busy: feedbackBusy,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({
    required this.quote,
    required this.showDivider,
    required this.baseStyle,
    required this.highlightStyle,
    required this.highlightTerms,
  });

  final InlineEvidenceQuote quote;
  final bool showDivider;
  final TextStyle baseStyle;
  final TextStyle highlightStyle;
  final List<String> highlightTerms;

  @override
  Widget build(BuildContext context) {
    final dateLabel = quote.recordedAt.millisecondsSinceEpoch == 0
        ? 'Date unavailable'
        : InlineEvidenceDrawerWidget._timeFormat.format(
            quote.recordedAt.toLocal(),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                dateLabel,
                style: VoiceMemoryTypography.metadataStyle(
                  color: VoiceMemoryColors.textSecondary,
                ),
              ),
            ),
            if (quote.roleLabel != null)
              Text(
                quote.roleLabel!,
                style: VoiceMemoryTypography.secondaryStyle(
                  color: VoiceMemoryColors.primaryIndigo,
                ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 6),
        RichText(
          text: EvidenceKeywordHighlighter.buildHighlightedSpan(
            quote: quote.verbatimText,
            highlightTerms: highlightTerms,
            baseStyle: baseStyle,
            highlightStyle: highlightStyle,
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          key: Key('inline_evidence_open_entry_${quote.entryId}'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
          onPressed: quote.entryId.isEmpty
              ? null
              : () => context.push('/entry/${quote.entryId}'),
          child: Text(
            'Open ${formatUserFacingDate(quote.recordedAt)} recording',
            style: VoiceMemoryTypography.bodyStyle(
              color: VoiceMemoryColors.primaryIndigo,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        if (showDivider) ...[
          const SizedBox(height: AppSpacing.sm),
          Divider(color: VoiceMemoryColors.border.withValues(alpha: 0.8)),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}