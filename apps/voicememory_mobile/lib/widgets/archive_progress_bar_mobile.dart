import 'package:flutter/material.dart';

import '../features/archive_maturity/archive_maturity_engine.dart';
import '../models/journal_entry.dart';
import '../theme/voicememory_colors.dart';

/// Dominant unified archive progress on mobile.
class ArchiveProgressBarMobile extends StatelessWidget {
  const ArchiveProgressBarMobile({super.key, required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final view = ArchiveMaturityEngine.buildView(
      ArchiveMaturityEngine.inputFromEntries(entries),
    );

    return Card(
      color: VoiceMemoryColors.surface,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              view.headline,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: VoiceMemoryColors.textPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Current stage · ${view.stageLabel}',
              style: const TextStyle(
                fontSize: 10,
                color: VoiceMemoryColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: view.score / 100,
                minHeight: 8,
                backgroundColor: VoiceMemoryColors.surfaceSecondary,
                color: VoiceMemoryColors.primaryIndigo,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${view.score}%',
              style: const TextStyle(
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
                color: VoiceMemoryColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Next milestone (${view.nextMilestonePercent}%): ${view.nextMilestoneLabel}',
              style: const TextStyle(
                fontSize: 11,
                color: VoiceMemoryColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
