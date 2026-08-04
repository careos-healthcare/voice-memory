import 'package:flutter/material.dart';

import '../features/archive_reputation/archive_reputation.dart';
import '../models/journal_entry.dart';
import '../theme/app_theme.dart';
import '../theme/voicememory_colors.dart';

/// Archive reputation on mobile archive surfaces.
class ArchiveReputationCardMobile extends StatelessWidget {
  const ArchiveReputationCardMobile({
    super.key,
    required this.entries,
    this.compact = false,
  });

  final List<JournalEntry> entries;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final view = ArchiveReputationEngine.build(entries);
    if (view == null) return const SizedBox.shrink();

    final filled = ((view.meterFill / 100) * 28).round().clamp(1, 28);

    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ARCHIVE REPUTATION',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.muted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'My archive has earned the right to believe this.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Level',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ArchiveReputationEngine.levelLabel(view.level),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: List.generate(28, (index) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: index < filled
                        ? VoiceMemoryColors.primaryIndigo.withValues(
                            alpha: 0.65,
                          )
                        : VoiceMemoryColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Text(
              view.summary,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              "The archive's confidence in this belief depends on the evidence available.",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
            if (!compact) ...[
              const SizedBox(height: 12),
              _metricRow(
                context,
                'Supporting moments',
                view.supportingReflections,
              ),
              _metricRow(context, 'Life areas', view.lifeAreas),
              _metricRow(context, 'Days tracked', view.daysTracked),
              _metricRow(
                context,
                'Contradictions survived',
                view.contradictionsSurvived,
              ),
              _metricRow(
                context,
                'Belief revisions',
                view.beliefChangesObserved,
              ),
              _metricRow(context, 'Accuracy signals', view.accuracySignals),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricRow(BuildContext context, String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 12),
          Text('$value', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
