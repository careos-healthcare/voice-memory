import 'dart:async';

import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_confidence_band_copy.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_v1/inline_evidence_quote.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Detail payload for the insight evidence sheet.
class InsightEvidenceDetailPayload {
  const InsightEvidenceDetailPayload({
    required this.insightText,
    required this.confidenceBand,
    required this.quotes,
  });

  final String insightText;
  final PatternMatchConfidenceBand confidenceBand;
  final List<InlineEvidenceQuote> quotes;
}

/// Evidence-trail detail: confidence band, chronological source spans, jump to entry.
class InsightEvidenceDetailSheet extends StatelessWidget {
  const InsightEvidenceDetailSheet({
    required this.payload,
    super.key,
  });

  final InsightEvidenceDetailPayload payload;

  static Future<void> show(
    BuildContext context, {
    required InsightEvidenceDetailPayload payload,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InsightEvidenceDetailSheet(payload: payload),
    );
  }

  List<InlineEvidenceQuote> get _chronologicalQuotes {
    final sorted = [...payload.quotes]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bandLabel = EvidenceConfidenceBandCopy.labelFor(
      band: payload.confidenceBand,
      sourceCount: payload.quotes.length,
    );
    final bandSummary = EvidenceConfidenceBandCopy.summaryFor(
      band: payload.confidenceBand,
      sourceCount: payload.quotes.length,
    );
    final quotes = _chronologicalQuotes;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Material(
          key: const Key('insight_evidence_detail_sheet'),
          color: VoiceMemoryColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VoiceMemoryColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Show evidence',
                        style: VoiceMemoryTypography.pageTitleStyle().copyWith(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomInset),
                  children: [
                    Text(
                      payload.insightText,
                      style: VoiceMemoryTypography.cardTitleStyle(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      key: Key('insight_evidence_confidence_band_$bandLabel'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VoiceMemoryColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: VoiceMemoryColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bandLabel,
                            style: VoiceMemoryTypography.cardTitleStyle()
                                .copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bandSummary,
                            style: VoiceMemoryTypography.bodyStyle(
                              color: VoiceMemoryColors.textSecondary,
                            ).copyWith(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SOURCE TRANSCRIPTS',
                      style: VoiceMemoryTypography.sectionLabelStyle(),
                    ),
                    const SizedBox(height: 10),
                    if (quotes.isEmpty)
                      Text(
                        'No linked journal entries yet.',
                        style: VoiceMemoryTypography.bodyStyle(
                          color: VoiceMemoryColors.textSecondary,
                        ),
                      )
                    else
                      for (final quote in quotes)
                        _SourceSpanCard(quote: quote),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SourceSpanCard extends StatelessWidget {
  const _SourceSpanCard({required this.quote});

  final InlineEvidenceQuote quote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('insight_evidence_source_${quote.entryId}'),
          onTap: () {
            unawaited(context.push('/entry/${quote.entryId}'));
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: VoiceMemoryColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatUserFacingDate(quote.recordedAt),
                  style: VoiceMemoryTypography.secondaryStyle(
                    color: VoiceMemoryColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  quote.verbatimText,
                  style: VoiceMemoryTypography.bodyStyle().copyWith(
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Open journal entry',
                  style: VoiceMemoryTypography.bodyStyle(
                    color: VoiceMemoryColors.primaryIndigo,
                  ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
