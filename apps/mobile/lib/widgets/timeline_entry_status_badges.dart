import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/timeline_sync_badge.dart';
import 'package:flutter/material.dart';

/// Status pills for timeline cards — sync state and transcript quality.
class TimelineEntryStatusBadges extends StatelessWidget {
  const TimelineEntryStatusBadges({required this.entry, super.key});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final labels = timelineEntryStatusBadgeLabels(entry);
    if (labels.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final label in labels) TimelineSyncBadge(label: label),
      ],
    );
  }
}