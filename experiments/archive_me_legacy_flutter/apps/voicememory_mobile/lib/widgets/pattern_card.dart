import 'package:flutter/material.dart';

import '../features/immediate_archive_value/immediate_archive_value_engine.dart';
import '../models/journal_entry.dart';
import '../theme/app_theme.dart';
import 'archive_insight_card_shell.dart';

/// Recording #3+ — early recurring patterns (shown from 3 recordings).
class PatternCard extends StatelessWidget {
  const PatternCard({super.key, required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final pattern = buildThirdRecordingPattern(entries);
    final lines = pattern.lines.isEmpty
        ? const ['Record one more moment so recurring themes can be confirmed.']
        : pattern.lines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveInsightCardShell(
          sectionTitle: 'Early pattern',
          headline: pattern.headline,
          children: [
            ...lines.map((line) => ArchiveInsightBullet(text: line)),
            if (pattern.hasEvidence) ...[
              const SizedBox(height: 4),
              Text(
                pattern.footer,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 13,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
