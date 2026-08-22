import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/archive_momentum_section.dart';
import 'package:archiveme_mobile/widgets/archive_quick_explain_card.dart';
import 'package:archiveme_mobile/widgets/comparison_card.dart';
import 'package:archiveme_mobile/widgets/first_archive_insight_section.dart';
import 'package:archiveme_mobile/widgets/pattern_card.dart';
import 'package:flutter/material.dart';

/// Progressive archive value for recordings 1–4.
class ImmediateArchiveValueSections extends StatelessWidget {
  const ImmediateArchiveValueSections({required this.entries, super.key});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final count = entries.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveQuickExplainCard(reflectionCount: count),
        const SizedBox(height: 20),
        FirstArchiveInsightSection(entries: entries),
        if (count >= 2) ...[
          const SizedBox(height: 20),
          ComparisonCard(entries: entries),
        ],
        if (count >= 3) ...[
          const SizedBox(height: 20),
          PatternCard(entries: entries),
        ],
        if (count >= 4) ...[
          const SizedBox(height: 20),
          ArchiveMomentumSection(entries: entries),
        ],
      ],
    );
  }
}