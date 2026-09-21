import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_copy.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_model.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/transcript_evidence_index.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/verbatim_evidence.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/legacy_provenance_notice.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/provenance_recovery_action.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/source_quote_chip.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/view_source_proof_section.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Belief-change pattern card.
///
/// Each half of the comparison shows the stored words behind it inline, and the
/// card carries one source-proof link covering both. The claim lines themselves
/// hold no citation marker: they are the archive's read, and the quotes below
/// are what that read is allowed to rest on.
class BeliefChangePatternCard extends StatelessWidget {
  const BeliefChangePatternCard({
    required this.moment,
    super.key,
    this.compact = false,
    this.footer,
    this.trailing,
    this.recoveryBuilder,
  });

  final BeliefChangeMoment moment;
  final bool compact;
  final Widget? footer;
  final Widget? trailing;

  /// Same injection as [EvidenceCitationList.recoveryBuilder].
  final Widget Function(BuildContext context, List<String> entryIds)?
  recoveryBuilder;

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

    final earlierEvidence = _verify(moment.earlierSnippet);
    final laterEvidence = _verify(moment.laterSnippet);
    final verified = [?earlierEvidence, ?laterEvidence];

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
          Text(BeliefChangeMomentCopy.title, style: titleStyle),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(BeliefChangeMomentCopy.body, style: bodyStyle),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(BeliefChangeMomentCopy.beliefLine, style: labelStyle),
          const SizedBox(height: 2),
          Text('"${moment.earlierBeliefExample}"', style: exampleStyle),
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
          Text('"${moment.changeExample}"', style: exampleStyle),
          if (laterEvidence != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SourceQuoteChip(evidence: laterEvidence),
            ),
          ],
          if (verified.isEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _emptyVerifyNotice(context),
          ] else
            ViewSourceProofSection(
              evidence: verified,
              claimContext: BeliefChangeMomentCopy.title,
            ),
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

  Widget _emptyVerifyNotice(BuildContext context) {
    final lines = _linesFor(moment);
    if (EvidenceCitationList.stateFor(lines) ==
        EvidenceCitationState.provenanceUnverified) {
      return LegacyProvenanceNotice(
        recovery: _effectiveRecoveryBuilder?.call(
          context,
          EvidenceCitationList.legacyEntryIds(lines),
        ),
      );
    }
    return UngroundedEvidenceNotice(
      failure: _failureFor(moment.earlierSnippet),
    );
  }

  Widget Function(BuildContext context, List<String> entryIds)?
  get _effectiveRecoveryBuilder =>
      recoveryBuilder ??
      (V1CapabilityRegistry.provenanceRecovery
          ? ProvenanceRecoveryAction.productionBuilder
          : null);

  static List<InsightEvidenceLine> _linesFor(BeliefChangeMoment moment) {
    InsightEvidenceLine line(BeliefChangeEvidenceSnippet snippet) =>
        InsightEvidenceLine(
          entryId: snippet.entryId,
          quote: snippet.quote,
          recordedAt:
              TranscriptEvidenceIndex.recordedAtFor(snippet.entryId) ??
              DateTime.fromMillisecondsSinceEpoch(0),
          label: snippet.label,
        );
    return [line(moment.earlierSnippet), line(moment.laterSnippet)];
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
