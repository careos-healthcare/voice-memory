import 'dart:async';

import 'package:archiveme_mobile/features/belief_evidence/evidence/journal_transcript_evidence_indexer.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/view_source_proof_section.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_hooks.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_display_gate.dart';
import 'package:archiveme_mobile/features/proof_admission/verified_proof_view_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/widgets/proof/proof_detail_sheet.dart';
import 'package:archiveme_mobile/widgets/proof/verified_proof_correction_controls.dart';
import 'package:flutter/material.dart';

/// Archive's restrained proof/change cards section.
///
/// Renders nothing at all unless [ProofDisplayGate] currently admits at
/// least one entry's proof — see `docs/ARCHIVE_SCREEN_SPEC_V1.md` hard rule
/// 1. Every line shown here comes from [VerifiedProofViewModel]; nothing in
/// this widget reads a raw reflection field, receipt internal, or any
/// legacy interpretation engine.
class ArchiveVerifiedChangesSection extends StatelessWidget {
  const ArchiveVerifiedChangesSection({
    required this.proofCandidates,
    required this.proofContextEntries,
    super.key,
    this.gate = const ProofDisplayGate(),
    this.maxItems = 5,
  });

  /// Backward-compatible alias for callers that still pass one combined list.
  ArchiveVerifiedChangesSection.fromEntries({
    required List<JournalEntry> entries,
    super.key,
    ProofDisplayGate gate = const ProofDisplayGate(),
    int maxItems = 5,
  }) : proofCandidates = entries
           .where((entry) => entry.verifiedProof != null)
           .toList(),
       proofContextEntries = entries,
       gate = gate,
       maxItems = maxItems;

  static const String heading = 'Changes your archive noticed';
  static const String subheading =
      'Based on these entries — your saved words stay separate from this read.';
  static const String archiveReadLabel = 'Your archive noticed';
  static const String yourWordsLabel = 'Your words';
  static const String correctionHint = 'You can correct or hide this.';

  final List<JournalEntry> proofCandidates;
  final List<JournalEntry> proofContextEntries;
  final ProofDisplayGate gate;

  /// Keeps this a restrained section rather than an unbounded feed.
  final int maxItems;

  List<({JournalEntry entry, VerifiedProofViewModel view})> _admittedViews() {
    final withProof = proofCandidates.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final admitted = <({JournalEntry entry, VerifiedProofViewModel view})>[];
    for (final entry in withProof) {
      if (admitted.length >= maxItems) break;
      final view = gate.viewFor(
        proof: entry.verifiedProof!,
        entries: proofContextEntries,
      );
      if (view == null) continue;
      final statement = view.statement.trim();
      if (statement.isEmpty) continue;
      admitted.add((entry: entry, view: view));
    }
    return admitted;
  }

  @override
  Widget build(BuildContext context) {
    final admitted = _admittedViews();
    if (admitted.isEmpty) return const SizedBox.shrink();

    // A proof quote can only be checked against text this process actually
    // holds. The entries backing these cards are already in memory here, so
    // registering their stored transcripts is what makes verification possible
    // at all on this screen — without it every quote would read as unverified
    // and the source-proof link would correctly refuse to appear.
    JournalTranscriptEvidenceIndexer.rememberAll(proofContextEntries);

    unawaited(
      BetaAnalyticsHooks.possiblePatternViewed(surface: 'archive_changes'),
    );

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            key: const Key('archive_verified_changes_heading'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            subheading,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in admitted)
            _VerifiedChangeCard(
              key: Key('archive_verified_change_${item.entry.id}'),
              entry: item.entry,
              view: item.view,
            ),
        ],
      ),
    );
  }
}

class _VerifiedChangeCard extends StatelessWidget {
  const _VerifiedChangeCard({
    required this.entry, required this.view, super.key,
  });

  final JournalEntry entry;
  final VerifiedProofViewModel view;

  void _openDetail(BuildContext context) {
    unawaited(
      ProofDetailSheet.show(
        context,
        proof: view,
        correctionControls: VerifiedProofCorrectionControls(
          proof: entry.verifiedProof!,
          sourceSurface: 'archive_verified_changes',
        ),
      ),
    );
  }

  /// The receipt's supporting snapshots as citation candidates.
  ///
  /// These are candidates only: each one is checked against the stored
  /// transcript before anything is drawn, so a snapshot whose quote no longer
  /// matches the saved words contributes no link and no count.
  List<InsightEvidenceLine> get _evidenceLines => [
    for (final evidence in view.supportingEvidence)
      InsightEvidenceLine(
        entryId: evidence.sourceEntryId,
        quote: evidence.quote,
        recordedAt: evidence.sourceDate,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The card body keeps its existing job — proof details, evidence, and
          // the correction controls. The source-proof link below is a sibling
          // rather than a child so it is a real single tap and, unlike before,
          // is not swallowed by this button's semantics.
          Semantics(
            button: true,
            label:
                '${ArchiveVerifiedChangesSection.archiveReadLabel}: '
                '${view.statement}. ${view.confidenceLabel}.',
            hint: 'Opens proof details, evidence, and correction controls',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openDetail(context),
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            view.confidenceLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ArchiveVerifiedChangesSection.archiveReadLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '"${view.statement}"',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ViewSourceProofSection.fromLines(
                  lines: _evidenceLines,
                  claimContext: view.statement,
                ),
                const SizedBox(height: 8),
                Text(
                  ArchiveVerifiedChangesSection.correctionHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
