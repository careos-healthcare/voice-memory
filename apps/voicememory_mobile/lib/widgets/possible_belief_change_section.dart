import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/warm_archive_copy.dart';
import '../features/archive_evidence/archive_evidence.dart';
import '../features/contradiction_detection/contradiction_detection_service.dart';
import '../features/contradiction_detection/contradiction_report.dart';
import '../models/journal_entry.dart';
import '../features/archive_explanations/explanation_models.dart';
import '../theme/app_theme.dart';
import 'archive_why_button.dart';

/// Archive section — contradiction-backed possible belief change.
class PossibleBeliefChangeSection extends StatelessWidget {
  const PossibleBeliefChangeSection({
    super.key,
    required this.entries,
    this.currentBelief,
  });

  final List<JournalEntry> entries;
  final String? currentBelief;

  @override
  Widget build(BuildContext context) {
    if (!archiveHasMinimumEvidence(entries)) return const SizedBox.shrink();

    final result = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: currentBelief,
    );

    if (!result.hasPossibleBeliefChange) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'POSSIBLE BELIEF CHANGE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppTheme.muted,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'The archive found tension between earlier and later recordings — '
          'not a verdict, a signal to review.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        ...result.reports.map((r) => _ContradictionCard(report: r)),
      ],
    );
  }
}

class _ContradictionCard extends StatelessWidget {
  const _ContradictionCard({required this.report});

  final ContradictionReport report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.compare_arrows,
                    size: 18,
                    color: Colors.amber.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Possible Belief Change',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    WarmArchiveCopy.confidenceStrengthLine(
                      report.confidenceScore,
                    ),
                    style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                  ArchiveWhyButton(
                    ref: ArchiveInsightRef.contradiction(
                      entryIdA: report.originalEntryId,
                      entryIdB: report.conflictingEntryId,
                    ),
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                report.kind.label,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
              if (report.sharedThemes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Themes: ${report.sharedThemes.join(', ')}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Earlier',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '"${report.originalStatement}"',
                style: const TextStyle(color: AppTheme.muted, height: 1.4),
              ),
              const SizedBox(height: 10),
              const Icon(Icons.arrow_downward, size: 16, color: AppTheme.muted),
              const SizedBox(height: 10),
              const Text(
                'Later',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '"${report.conflictingStatement}"',
                style: const TextStyle(color: AppTheme.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in report.recordingIds)
                    OutlinedButton(
                      onPressed: () => context.push('/entry/$id'),
                      child: const Text('View recording'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
