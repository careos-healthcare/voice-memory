import 'package:archiveme_mobile/features/immediate_archive_value/immediate_archive_value_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/archive_insight_card_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Recording #4 — progress toward working belief.
class ArchiveMomentumSection extends StatelessWidget {
  const ArchiveMomentumSection({required this.entries, super.key});

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
            ArchiveInsightField(
              label: 'Progress',
              value: momentum.progressLabel,
            ),
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