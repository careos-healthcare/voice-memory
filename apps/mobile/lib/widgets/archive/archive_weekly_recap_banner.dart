import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// Short week-in-review shown when the week has just ended.
class ArchiveWeeklyRecapBanner extends StatelessWidget {
  const ArchiveWeeklyRecapBanner({required this.entries, super.key});

  final List<JournalEntry> entries;

  static bool weekJustEnded(DateTime now) =>
      now.weekday == DateTime.sunday || now.weekday == DateTime.monday;

  static List<JournalEntry> entriesThisWeek(List<JournalEntry> entries, DateTime now) {
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    return entries.where((entry) => !entry.createdAt.toLocal().isBefore(start)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (!weekJustEnded(now)) return const SizedBox.shrink();
    final week = entriesThisWeek(entries, now);
    if (week.isEmpty) return const SizedBox.shrink();
    final latest = week.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
    final words = latest.transcript.trim();
    final snippet = words.length > 80 ? '${words.substring(0, 80)}…' : words;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        key: const Key('archive_weekly_recap'),
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This week', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(
                '${week.length} saved ${week.length == 1 ? 'moment' : 'moments'}.',
                style: theme.textTheme.titleMedium,
              ),
              if (snippet.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(snippet, style: theme.textTheme.bodyMedium),
                ViewEvidenceInlineLink(
                  entryIds: [latest.id],
                  surface: 'weekly_recap',
                  claimContext: 'This week',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
