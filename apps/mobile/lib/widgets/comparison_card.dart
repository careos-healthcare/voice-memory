import 'package:archiveme_mobile/features/immediate_archive_value/immediate_archive_value_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/archive_insight_card_shell.dart';
import 'package:flutter/material.dart';

/// Recording #2 — cross-recording comparison.
class ComparisonCard extends StatelessWidget {
  const ComparisonCard({required this.entries, super.key});

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