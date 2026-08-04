import 'package:flutter/material.dart';

import '../models/journal_entry.dart';
import '../widgets/archive_quick_explain_card.dart';
import 'archive_momentum_section.dart';
import 'comparison_card.dart';
import 'first_archive_insight_section.dart';
import 'pattern_card.dart';

/// Progressive archive value for recordings 1–4.
class ImmediateArchiveValueSections extends StatelessWidget {
  const ImmediateArchiveValueSections({super.key, required this.entries});

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
