import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/insights/services/local_recap_generator.dart';
import 'package:archiveme_mobile/features/insights/views/weekly_recap_view.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// Short week-in-review shown when the week has just ended.
class ArchiveWeeklyRecapBanner extends StatelessWidget {
  const ArchiveWeeklyRecapBanner({required this.entries, super.key});

  final List<JournalEntry> entries;

  static bool weekJustEnded(DateTime now) =>
      now.weekday == DateTime.sunday || now.weekday == DateTime.monday;

  static List<JournalEntry> entriesThisWeek(
    List<JournalEntry> entries,
    DateTime now,
  ) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    return entries
        .where((entry) => !entry.createdAt.toLocal().isBefore(start))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.weeklyRecapBanner) return const SizedBox.shrink();
    final now = DateTime.now();
    if (!weekJustEnded(now)) return const SizedBox.shrink();
    final week = entriesThisWeek(entries, now);
    if (week.isEmpty) return const SizedBox.shrink();
    final recap = const LocalRecapGenerator().build(entries, now: now);
    final theme = Theme.of(context);
    final claim =
        '${recap.daysRecorded} ${recap.daysRecorded == 1 ? 'day' : 'days'} · ${recap.totalMinutes} ${recap.totalMinutes == 1 ? 'minute' : 'minutes'}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        key: const Key('archive_weekly_recap'),
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WeeklyRecapView(entries: entries, now: now),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This week', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(claim, style: theme.textTheme.titleMedium),
                ViewEvidenceInlineLink(
                  entryIds: [for (final entry in week) entry.id],
                  surface: 'weekly_recap',
                  claimContext: claim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
