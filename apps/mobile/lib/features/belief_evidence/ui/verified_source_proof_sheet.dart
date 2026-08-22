import 'dart:async';

import 'package:archiveme_mobile/features/belief_evidence/evidence/verbatim_evidence.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trust_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// The one sheet every claim surface uses to show the words behind a claim.
///
/// It is built from [VerbatimEvidence], which only [VerbatimEvidenceVerifier]
/// can produce, and it renders each quote through [EvidenceCitationCard]. Both
/// facts are load-bearing: there is no parameter here that accepts a bare
/// string, so no caller can route generated or paraphrased text into a surface
/// a user reads as "here are my own words".
class VerifiedSourceProofSheet extends StatelessWidget {
  const VerifiedSourceProofSheet({
    required this.evidence,
    super.key,
    this.claimContext,
    this.onOpenEntry,
  });

  final List<VerbatimEvidence> evidence;

  /// The claim these quotes were cited for, repeated at the top of the sheet so
  /// the quotes are read against the thing they are supposed to support.
  final String? claimContext;

  final ValueChanged<String>? onOpenEntry;

  static const Key sheetKey = Key('verified_source_proof_sheet');

  /// Opens the sheet, or does nothing when [evidence] is empty.
  ///
  /// Returns whether a sheet was opened. Refusing to open on empty input is the
  /// point: an empty proof sheet would answer "show me the words behind this"
  /// with silence, which reads as proof having existed and been withheld.
  static Future<bool> showEvidence(
    BuildContext context, {
    required List<VerbatimEvidence> evidence,
    String? claimContext,
    ValueChanged<String>? onOpenEntry,
  }) async {
    if (evidence.isEmpty) return false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => VerifiedSourceProofSheet(
        evidence: evidence,
        claimContext: claimContext,
        onOpenEntry: onOpenEntry,
      ),
    );
    return true;
  }

  /// Verifies [lines] against stored transcripts, then opens the sheet.
  ///
  /// Lines that are not present word for word in a stored transcript are
  /// dropped rather than shown, so a partly-grounded claim shows only the part
  /// it can prove.
  static Future<bool> show(
    BuildContext context, {
    required List<InsightEvidenceLine> lines,
    String? claimContext,
    ValueChanged<String>? onOpenEntry,
  }) => showEvidence(
    context,
    evidence: verifiedFrom(lines),
    claimContext: claimContext,
    onOpenEntry: onOpenEntry,
  );

  /// The quotes [lines] can prove. Empty means there is nothing to show.
  static List<VerbatimEvidence> verifiedFrom(List<InsightEvidenceLine> lines) =>
      VerbatimEvidenceVerifier.groundLines(lines);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sorted = [...evidence]..sort((a, b) {
      final aDate = a.recordedAt;
      final bDate = b.recordedAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Material(
          key: VerifiedSourceProofSheet.sheetKey,
          color: AppColors.backgroundPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        EvidenceTrustCopy.viewSourceProof,
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
                    if (claimContext case final contextText?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          contextText,
                          style: VoiceMemoryTypography.bodyStyle(
                            color: AppColors.textSecondary,
                          ).copyWith(height: 1.45),
                        ),
                      ),
                    Text(
                      EvidenceTrustCopy.sheetLead,
                      style: VoiceMemoryTypography.bodyStyle(
                        color: AppColors.textMuted,
                      ).copyWith(height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (var i = 0; i < sorted.length; i++)
                      Padding(
                        key: Key('verified_source_proof_excerpt_$i'),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: EvidenceCitationCard(
                          evidence: sorted[i],
                          onOpenEntry: onOpenEntry,
                          initiallyExpanded: true,
                        ),
                      ),
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

/// The single one-tap affordance for opening a claim's source proof.
///
/// Every pattern, belief-change, and insight surface uses this rather than
/// wiring its own gesture, so the behaviour cannot drift per card. It renders
/// nothing at all when there is no verifiable quote: an affordance promising
/// proof must exist only where the proof does, otherwise tapping it would imply
/// grounding the archive does not have.
class VerifiedSourceProofLink extends StatelessWidget {
  const VerifiedSourceProofLink({
    required this.evidence,
    super.key,
    this.claimContext,
    this.onOpenEntry,
    this.showCount = true,
  });

  /// Verifies [lines] up front so the affordance and the sheet it opens are
  /// decided by the same evidence.
  factory VerifiedSourceProofLink.fromLines({
    required List<InsightEvidenceLine> lines,
    Key? key,
    String? claimContext,
    ValueChanged<String>? onOpenEntry,
    bool showCount = true,
  }) => VerifiedSourceProofLink(
    evidence: VerifiedSourceProofSheet.verifiedFrom(lines),
    key: key,
    claimContext: claimContext,
    onOpenEntry: onOpenEntry,
    showCount: showCount,
  );

  final List<VerbatimEvidence> evidence;
  final String? claimContext;
  final ValueChanged<String>? onOpenEntry;

  /// Whether to prefix the link with the number of verified sources.
  final bool showCount;

  /// Matches the platform minimum so the link is reachable with a thumb even
  /// though its text is small.
  static const double minTapTarget = 48;

  static const Key linkKey = Key('verified_source_proof_link');

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final countLabel = EvidenceTrustCopy.sourceCount(evidence.length);
    final label = showCount
        ? '$countLabel \u00B7 ${EvidenceTrustCopy.viewSourceProof}'
        : EvidenceTrustCopy.viewSourceProof;

    return Semantics(
      button: true,
      label: '$countLabel. ${EvidenceTrustCopy.viewSourceProof}',
      excludeSemantics: true,
      child: InkWell(
        key: VerifiedSourceProofLink.linkKey,
        onTap: () => unawaited(
          VerifiedSourceProofSheet.showEvidence(
            context,
            evidence: evidence,
            claimContext: claimContext,
            onOpenEntry: onOpenEntry,
          ),
        ),
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: VerifiedSourceProofLink.minTapTarget,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                label,
                style: style?.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textMuted.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
