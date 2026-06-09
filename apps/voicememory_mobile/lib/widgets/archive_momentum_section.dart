import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/immediate_archive_value/immediate_archive_value_engine.dart';
import '../models/journal_entry.dart';
import 'archive_insight_card_shell.dart';

/// Recording #4 — progress toward working belief.
class ArchiveMomentumSection extends StatelessWidget {
  const ArchiveMomentumSection({
    super.key,
    required this.entries,
  });

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final momentum = buildArchiveMomentum(entries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveInsightCardShell(
          sectionTitle: 'Archive momentum',
          children: [
            ArchiveInsightField(label: 'Progress', value: momentum.progressLabel),
            ArchiveInsightField(
              label: 'Archive confidence',
              value: momentum.confidenceLabel,
            ),
            ArchiveInsightBullet(text: momentum.body),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.go('/record'),
          child: const Text('Add another reflection'),
        ),
      ],
    );
  }
}
