import 'package:flutter/material.dart';

import '../../features/proof_admission/proof_display_gate.dart';
import '../../features/proof_admission/verified_proof_view_model.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../proof/proof_detail_sheet.dart';
import '../proof/verified_proof_correction_controls.dart';

/// Archive's restrained "Verified changes" section.
///
/// Renders nothing at all unless [ProofDisplayGate] currently admits at
/// least one entry's proof — see `docs/ARCHIVE_SCREEN_SPEC_V1.md` hard rule
/// 1. Every line shown here comes from [VerifiedProofViewModel]; nothing in
/// this widget reads a raw reflection field, receipt internal, or any
/// legacy interpretation engine.
class ArchiveVerifiedChangesSection extends StatelessWidget {
  const ArchiveVerifiedChangesSection({
    super.key,
    required this.entries,
    this.gate = const ProofDisplayGate(),
    this.maxItems = 5,
  });

  static const String heading = 'Verified changes';
  static const String subheading =
      'Changes your archive has confirmed with exact evidence.';

  final List<JournalEntry> entries;
  final ProofDisplayGate gate;

  /// Keeps this a restrained section rather than an unbounded feed.
  final int maxItems;

  List<({JournalEntry entry, VerifiedProofViewModel view})> _admittedViews() {
    final withProof =
        entries.where((entry) => entry.verifiedProof != null).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final admitted = <({JournalEntry entry, VerifiedProofViewModel view})>[];
    for (final entry in withProof) {
      if (admitted.length >= maxItems) break;
      final view = gate.viewFor(proof: entry.verifiedProof!, entries: entries);
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
    super.key,
    required this.entry,
    required this.view,
  });

  final JournalEntry entry;
  final VerifiedProofViewModel view;

  void _openDetail(BuildContext context) {
    ProofDetailSheet.show(
      context,
      proof: view,
      correctionControls: VerifiedProofCorrectionControls(
        proof: entry.verifiedProof!,
        sourceSurface: 'archive_verified_changes',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final evidence = view.supportingEvidence.firstOrNull;
    return Semantics(
      button: true,
      label: 'Verified change: ${view.statement}. ${view.confidenceLabel}.',
      hint: 'Opens proof details and evidence',
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: theme.colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openDetail(context),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                  Text('"${view.statement}"', style: theme.textTheme.bodyLarge),
                  if (evidence != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Because you said: "${evidence.quote}"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
