import 'package:flutter/material.dart';

import '../features/immediate_archive_value/immediate_archive_value_engine.dart';
import '../models/journal_entry.dart';
import 'archive_insight_card_shell.dart';

/// Recording #2 — cross-recording comparison.
class ComparisonCard extends StatelessWidget {
  const ComparisonCard({super.key, required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final comparison = buildSecondRecordingComparison(entries);
    final lines = comparison.lines.isEmpty
        ? const [
            'Keep recording — the archive will compare themes and language across entries.',
          ]
        : comparison.lines;

    return ArchiveInsightCardShell(
      sectionTitle: 'Comparison',
      headline: comparison.headline,
      children: lines.map((line) => ArchiveInsightBullet(text: line)).toList(),
    );
  }
}
