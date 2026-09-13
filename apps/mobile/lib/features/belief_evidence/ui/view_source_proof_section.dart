import 'package:archiveme_mobile/features/belief_evidence/evidence/verbatim_evidence.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/legacy_provenance_notice.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/verified_source_proof_sheet.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Block-level presentation of [VerifiedSourceProofLink] for use inside a card.
///
/// This is all a claim surface needs to add to become one tap from its proof.
/// It counts and opens *verified* quotes only, so when an engine hands over
/// supporting lines that are not present in any stored transcript the whole
/// section disappears rather than offering a link to nothing.
///
/// The exception is a legacy-only claim: the archive may still hold the
/// words, but their origin was never recorded. That is not "ungrounded", so
/// [ViewSourceProofSection.fromLines] renders [LegacyProvenanceNotice]
/// instead of shrinking.
class ViewSourceProofSection extends StatelessWidget {
  const ViewSourceProofSection({
    required this.evidence,
    super.key,
    this.showArchiveNoticed = false,
    this.claimContext,
    this.onOpenEntry,
    this.recoveryBuilder,
    this.lines,
  });

  /// Verifies [lines] before anything is drawn, so the count, the link, and the
  /// sheet all describe the same set of quotes.
  factory ViewSourceProofSection.fromLines({
    required List<InsightEvidenceLine> lines,
    Key? key,
    bool showArchiveNoticed = false,
    String? claimContext,
    ValueChanged<String>? onOpenEntry,
    Widget Function(BuildContext context, List<String> entryIds)?
    recoveryBuilder,
  }) => ViewSourceProofSection(
    evidence: VerifiedSourceProofSheet.verifiedFrom(lines),
    key: key,
    showArchiveNoticed: showArchiveNoticed,
    claimContext: claimContext,
    onOpenEntry: onOpenEntry,
    recoveryBuilder: recoveryBuilder,
    lines: lines,
  );

  final List<VerbatimEvidence> evidence;
  final bool showArchiveNoticed;
  final String? claimContext;
  final ValueChanged<String>? onOpenEntry;

  /// Same injection as [EvidenceCitationList.recoveryBuilder].
  final Widget Function(BuildContext context, List<String> entryIds)?
  recoveryBuilder;

  /// Original candidates, kept so an empty verified set can still be
  /// classified as legacy versus unsupported.
  final List<InsightEvidenceLine>? lines;

  static const Key sectionKey = Key('view_source_proof_section');

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty) {
      final sourceLines = lines;
      if (sourceLines != null &&
          EvidenceCitationList.stateFor(sourceLines) ==
              EvidenceCitationState.provenanceUnverified) {
        return LegacyProvenanceNotice(
          recovery: recoveryBuilder?.call(
            context,
            EvidenceCitationList.legacyEntryIds(sourceLines),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
      height: 1.4,
    );
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w600,
    );

    return Column(
      key: ViewSourceProofSection.sectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showArchiveNoticed) ...[
          Text(EvidenceTrustCopy.archiveNoticed, style: labelStyle),
          const SizedBox(height: 4),
        ],
        VerifiedSourceProofLink(
          evidence: evidence,
          claimContext: claimContext,
          onOpenEntry: onOpenEntry,
        ),
        // Counted from verified quotes rather than from what the engine
        // proposed, so this number can never overstate the evidence.
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            EvidenceTrustCopy.supportedByEntries(evidence.length),
            style: muted,
          ),
        ),
      ],
    );
  }
}
