import 'dart:async';

import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_v1/evidence_keyword_highlighter.dart';
import 'package:archiveme_mobile/widgets/archive_v1/evidence_pill.dart';
import 'package:archiveme_mobile/widgets/archive_v1/inline_evidence_drawer_widget.dart';
import 'package:archiveme_mobile/widgets/archive_v1/inline_evidence_quote.dart';
import 'package:archiveme_mobile/widgets/archive_v1/pattern_match_confidence_badge.dart';
import 'package:archiveme_mobile/widgets/evidence_trail/insight_evidence_detail_sheet.dart';
import 'package:flutter/material.dart';

/// Evidence-first insight card shell for archive feed surfaces.
class ArchiveInsightFeedCard extends StatefulWidget {
  const ArchiveInsightFeedCard({
    required this.insightText, required this.confidenceBand, required this.quotes, super.key,
    this.highlightTerms,
    this.headerLabel,
    this.borderColor,
    this.backgroundColor,
    this.footer,
    this.onAgree,
    this.onDisagree,
    this.onCorrect,
    this.feedbackBusy = false,
    this.onShowEvidence,
  });

  final String insightText;
  final PatternMatchConfidenceBand confidenceBand;
  final List<InlineEvidenceQuote> quotes;
  final List<String>? highlightTerms;
  final String? headerLabel;
  final Color? borderColor;
  final Color? backgroundColor;
  final Widget? footer;
  final VoidCallback? onAgree;
  final VoidCallback? onDisagree;
  final VoidCallback? onCorrect;
  final bool feedbackBusy;
  final VoidCallback? onShowEvidence;

  @override
  State<ArchiveInsightFeedCard> createState() => _ArchiveInsightFeedCardState();
}

class _ArchiveInsightFeedCardState extends State<ArchiveInsightFeedCard> {
  var _drawerExpanded = false;

  List<String> get _highlightTerms =>
      widget.highlightTerms ??
      EvidenceKeywordHighlighter.termsFromInsightText(widget.insightText);

  void _toggleDrawer() => setState(() => _drawerExpanded = !_drawerExpanded);

  void _openEvidenceDetail(BuildContext context) {
    if (widget.onShowEvidence != null) {
      widget.onShowEvidence!();
      return;
    }
    unawaited(
      InsightEvidenceDetailSheet.show(
        context,
        payload: InsightEvidenceDetailPayload(
          insightText: widget.insightText,
          confidenceBand: widget.confidenceBand,
          quotes: widget.quotes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('archive_insight_feed_card'),
      width: double.infinity,
      decoration: widget.backgroundColor == null && widget.borderColor == null
          ? VoiceMemoryCards.standard()
          : BoxDecoration(
              color: widget.backgroundColor ?? VoiceMemoryColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.borderColor ?? VoiceMemoryColors.border,
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.headerLabel != null) ...[
                        Text(
                          widget.headerLabel!,
                          style: VoiceMemoryTypography.sectionLabelStyle(
                            accent: VoiceMemoryColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        widget.insightText,
                        style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                          fontSize: 16,
                          height: 1.35,
                          color: VoiceMemoryColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                PatternMatchConfidenceBadge(band: widget.confidenceBand),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            EvidencePill(
              quoteCount: widget.quotes.length,
              expanded: _drawerExpanded,
              onTap: _toggleDrawer,
            ),
            if (_drawerExpanded)
              InlineEvidenceDrawerWidget(
                quotes: widget.quotes,
                highlightTerms: _highlightTerms,
                onAgree: widget.onAgree,
                onDisagree: widget.onDisagree,
                onCorrect: widget.onCorrect,
                feedbackBusy: widget.feedbackBusy,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('show_evidence_affordance'),
                onPressed: () => _openEvidenceDetail(context),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Show evidence'),
              ),
            ),
            if (widget.footer != null) ...[
              const SizedBox(height: AppSpacing.sm),
              widget.footer!,
            ],
          ],
        ),
      ),
    );
  }
}