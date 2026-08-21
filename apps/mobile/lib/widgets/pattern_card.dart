import 'package:archiveme_mobile/features/immediate_archive_value/immediate_archive_value_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive_insight_card_shell.dart';
import 'package:flutter/material.dart';

/// Recording #3+ — early recurring patterns (shown from 3 recordings).
class PatternCard extends StatelessWidget {
  const PatternCard({required this.entries, super.key});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final pattern = buildThirdRecordingPattern(entries);
    final lines = pattern.lines.isEmpty
        ? const [
            'Record one more reflection so recurring themes can be confirmed.',
          ]
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