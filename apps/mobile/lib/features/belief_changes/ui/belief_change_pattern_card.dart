import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_copy.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_model.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/transcript_evidence_index.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/verbatim_evidence.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/cited_claim_text.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/fact_ledger_resolved_citation.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/source_quote_chip.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Belief-change pattern card with inline fact-ledger citations per claim.
class BeliefChangePatternCard extends StatelessWidget {
  const BeliefChangePatternCard({
    required this.moment,
    super.key,
    this.compact = false,
    this.footer,
    this.trailing,
  });

  final BeliefChangeMoment moment;
  final bool compact;
  final Widget? footer;
  final Widget? trailing;

  static const Key cardKey = Key('belief_change_pattern_card');

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textSecondary);
    final exampleStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.4);

    final earlierCitation = FactLedgerResolvedCitation.fromEntryQuote(
      entryId: moment.earlierSnippet.entryId,
      quote: moment.earlierSnippet.quote,
      label: moment.earlierSnippet.label,
    );
    final laterCitation = FactLedgerResolvedCitation.fromEntryQuote(
      entryId: moment.laterSnippet.entryId,
      quote: moment.laterSnippet.quote,
      label: moment.laterSnippet.label,
    );
    final allCitations = [
      if (earlierCitation.quote.length >= 8) earlierCitation,
      if (laterCitation.quote.length >= 8) laterCitation,
    ];

    final earlierEvidence = _verify(moment.earlierSnippet);
    final laterEvidence = _verify(moment.laterSnippet);

    return Container(
      key: cardKey,
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF4FAF7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            EvidenceTrustCopy.archiveNoticed,
            style: labelStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          CitedClaimText(
            text: BeliefChangeMomentCopy.title,
            style: titleStyle,
            citations: allCitations,
            indicatorSuffix: 'title',
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.xs),
            CitedClaimText(
              text: BeliefChangeMomentCopy.body,
              style: bodyStyle,
              citations: allCitations,
              indicatorSuffix: 'body',
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(BeliefChangeMomentCopy.beliefLine, style: labelStyle),
          const SizedBox(height: 2),
          CitedClaimText(
            text: '"${moment.earlierBeliefExample}"',
            style: exampleStyle,
            citations: earlierCitation.quote.length >= 8
                ? [earlierCitation]
                : const [],
            claimContext: moment.earlierBeliefExample,
            indicatorSuffix: 'earlier_belief',
          ),
          if (earlierEvidence != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SourceQuoteChip(evidence: earlierEvidence),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(BeliefChangeMomentCopy.changeLine, style: labelStyle),
          const SizedBox(height: 2),
          CitedClaimText(
            text: '"${moment.changeExample}"',
            style: exampleStyle,
            citations: laterCitation.quote.length >= 8
                ? [laterCitation]
                : const [],
            claimContext: moment.changeExample,
            indicatorSuffix: 'change',
          ),
          if (laterEvidence != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SourceQuoteChip(evidence: laterEvidence),
            ),
          ],
          if (earlierEvidence == null && laterEvidence == null) ...[
            const SizedBox(height: AppSpacing.xs),
            UngroundedEvidenceNotice(
              failure: _failureFor(moment.earlierSnippet),
            ),
          ],
          if (!compact) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(BeliefChangeMomentCopy.footer, style: bodyStyle),
          ],
          ?footer,
          ?trailing,
        ],
      ),
    );
  }

  static EvidenceGrounding _ground(BeliefChangeEvidenceSnippet snippet) {
    return VerbatimEvidenceVerifier.verify(
      entryId: snippet.entryId,
      candidate: snippet.quote,
      sourceText: TranscriptEvidenceIndex.transcriptFor(snippet.entryId),
      recordedAt: TranscriptEvidenceIndex.recordedAtFor(snippet.entryId),
      label: snippet.label,
    );
  }

  static VerbatimEvidence? _verify(BeliefChangeEvidenceSnippet snippet) =>
      _ground(snippet).evidence;

  static EvidenceGroundingFailure _failureFor(
    BeliefChangeEvidenceSnippet snippet,
  ) =>
      _ground(snippet).failure ?? EvidenceGroundingFailure.sourceUnavailable;
}
