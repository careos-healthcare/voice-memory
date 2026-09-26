import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/weekly_recap/weekly_recap_builder.dart';
import 'package:archiveme_mobile/features/weekly_recap/weekly_recap_screen.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// Short week-in-review shown from Sunday morning through Tuesday night.
class ArchiveWeeklyRecapBanner extends StatelessWidget {
  const ArchiveWeeklyRecapBanner({
    required this.entries,
    this.now,
    super.key,
  });

  final List<JournalEntry> entries;
  final DateTime? now;

  static bool weekJustEnded(DateTime now) =>
      WeeklyRecapBuilder.bannerWindow(now);

  static List<JournalEntry> entriesThisWeek(
    List<JournalEntry> entries,
    DateTime now,
  ) {
    return WeeklyRecapBuilder.build(entries, now: now).entries;
  }

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.weeklyRecapBanner) return const SizedBox.shrink();
    final clock = now ?? DateTime.now();
    if (!weekJustEnded(clock)) return const SizedBox.shrink();
    final week = entriesThisWeek(entries, clock);
    if (week.isEmpty) return const SizedBox.shrink();
    final recap = WeeklyRecapBuilder.build(entries, now: clock);
    final theme = Theme.of(context);
    final claim =
        '${recap.daysRecorded} of 7 days · ${recap.totalMinutes} ${recap.totalMinutes == 1 ? 'minute' : 'minutes'}';
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
                builder: (_) => WeeklyRecapScreen(
                  entries: entries,
                  now: clock,
                ),
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
