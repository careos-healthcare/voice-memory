import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/warm_archive_copy.dart';
import '../features/archive_evidence/archive_evidence.dart';
import '../features/belief_shift/belief_shift_engine.dart';
import '../features/belief_shift/belief_shift_models.dart';
import '../models/journal_entry.dart';
import '../features/archive_explanations/explanation_models.dart';
import '../theme/app_theme.dart';
import 'archive_why_button.dart';

/// Archive section — major belief shifts with old → current and evidence chain.
class MajorBeliefChangesSection extends StatelessWidget {
  const MajorBeliefChangesSection({
    super.key,
    required this.entries,
    this.currentBelief,
  });

  final List<JournalEntry> entries;
  final String? currentBelief;

  @override
  Widget build(BuildContext context) {
    if (!archiveHasMinimumEvidence(entries)) return const SizedBox.shrink();

    final result = const BeliefShiftEngine().detect(
      entries: entries,
      currentBelief: currentBelief,
    );

    if (!result.hasMajorShifts) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          WarmArchiveCopy.beliefChangesSectionTitle,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppTheme.muted,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Gradual shifts the archive traced across recordings — each step is tied to real evidence.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        ...result.reports.map((r) => _BeliefShiftCard(report: r)),
      ],
    );
  }
}

class _BeliefShiftCard extends StatelessWidget {
  const _BeliefShiftCard({required this.report});

  final BeliefShiftReport report;

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
                    Icons.trending_up,
                    size: 18,
                    color: Colors.teal.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Major Belief Change',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    WarmArchiveCopy.confidenceStrengthLine(report.confidence),
                    style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                  if (report.evolutionTimeline.length >= 2)
                    ArchiveWhyButton(
                      ref: ArchiveInsightRef.contradiction(
                        entryIdA: report.evolutionTimeline.first.entryId,
                        entryIdB: report.evolutionTimeline.last.entryId,
                      ),
                      compact: true,
                    )
                  else
                    ArchiveWhyButton(
                      ref: ArchiveInsightRef.belief(),
                      compact: true,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                report.kind.label,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
              if (report.sharedTopics.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Themes: ${report.sharedTopics.join(', ')}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                'Old belief',
                style: TextStyle(fontSize: 10, letterSpacing: 0.6, color: AppTheme.muted),
              ),
              const SizedBox(height: 4),
              Text(
                '"${report.originalBelief}"',
                style: const TextStyle(color: AppTheme.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Icon(Icons.arrow_downward, size: 18, color: AppTheme.muted),
              const SizedBox(height: 12),
              const Text(
                'Current belief',
                style: TextStyle(fontSize: 10, letterSpacing: 0.6, color: AppTheme.muted),
              ),
              const SizedBox(height: 4),
              Text(
                '"${report.newBelief}"',
                style: const TextStyle(
                  color: AppTheme.foreground,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (report.evolutionTimeline.length > 2) ...[
                const SizedBox(height: 16),
                const Text(
                  'Evidence chain',
                  style: TextStyle(fontSize: 10, letterSpacing: 0.6, color: AppTheme.muted),
                ),
                const SizedBox(height: 10),
                ...report.evolutionTimeline.asMap().entries.map((entry) {
                  final i = entry.key;
                  final step = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (i > 0) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Icon(Icons.more_vert, size: 14, color: AppTheme.muted),
                        ),
                      ],
                      InkWell(
                        onTap: () => context.push('/entry/${step.entryId}'),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '"${step.beliefText}"',
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in report.evidenceIds)
                    OutlinedButton(
                      onPressed: () => context.push('/entry/$id'),
                      child: Text('Recording ${report.evidenceIds.indexOf(id) + 1}'),
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
