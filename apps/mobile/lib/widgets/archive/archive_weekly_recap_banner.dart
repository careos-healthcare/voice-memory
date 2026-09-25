import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
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
    if (!V1CapabilityRegistry.weeklyRecapBanner) return const SizedBox.shrink();
    final now = DateTime.now();
    if (!weekJustEnded(now)) return const SizedBox.shrink();
    final week = entriesThisWeek(entries, now);
    if (week.isEmpty) return const SizedBox.shrink();
    final arc = emotionalArc(week);
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
              if (arc.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(arc, key: const Key('archive_weekly_emotional_arc')),
                ViewEvidenceInlineLink(
                  entryIds: [for (final entry in week) entry.id],
                  surface: 'weekly_recap',
                  claimContext: arc,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Moods and lines from the whole week, not only the newest moment.
  static String emotionalArc(List<JournalEntry> week) {
    final ordered = [...week]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final moods = [
      for (final entry in ordered)
        if (entry.reflection.mood.trim().isNotEmpty) entry.reflection.mood.trim(),
    ];
    final uniqueMoods = moods.toSet().toList();
    if (uniqueMoods.length >= 2) {
      return '${uniqueMoods.first} to ${uniqueMoods.last} across ${ordered.length} moments.';
    }
    final lines = [
      for (final entry in ordered)
        if (entry.transcript.trim().isNotEmpty) _clip(entry.transcript.trim()),
    ];
    if (lines.length >= 2) {
      return 'Opened with “${lines.first}” and later “${lines.last}”.';
    }
    if (lines.length == 1) return lines.single;
    if (uniqueMoods.length == 1) return uniqueMoods.single;
    return '';
  }

  static String _clip(String words) =>
      words.length > 80 ? '${words.substring(0, 80)}…' : words;
}
