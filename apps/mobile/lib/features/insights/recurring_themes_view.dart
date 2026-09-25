import 'package:archiveme_mobile/features/insights/theme_frequency.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// Shows a recurring word pair and a link back to the moments that contain it.
class RecurringThemesView extends StatelessWidget {
  const RecurringThemesView({required this.entries, super.key});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final themes = ThemeFrequency.analyze([
      for (final entry in entries) (id: entry.id, text: entry.transcript),
    ]);
    if (themes.isEmpty) return const SizedBox.shrink();
    final theme = themes.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(theme.sentence, key: const Key('recurring_theme_sentence')),
          ViewEvidenceInlineLink(
            entryIds: theme.entryIds,
            surface: 'pattern_exploration',
            claimContext: theme.sentence,
          ),
        ],
      ),
    );
  }
}
