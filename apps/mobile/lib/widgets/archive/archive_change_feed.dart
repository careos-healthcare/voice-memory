import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/material.dart';

/// Saved-moment list used by the archive dashboard.
class ArchiveChangeFeed extends StatelessWidget {
  const ArchiveChangeFeed({
    required this.entries,
    this.itemBuilder,
    this.onEntryTap,
    this.trailing,
    this.showTitle = true,
    this.asSliver = false,
    super.key,
  });

  final List<JournalEntry> entries;
  final Widget Function(BuildContext context, JournalEntry entry)? itemBuilder;
  final ValueChanged<JournalEntry>? onEntryTap;
  final Widget? trailing;
  final bool showTitle;
  final bool asSliver;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final entry in entries)
        if (itemBuilder != null)
          itemBuilder!(context, entry)
        else
          const SizedBox.shrink(),
      ?trailing,
    ];
    if (asSliver) {
      return SliverList(delegate: SliverChildListDelegate(children));
    }
    return Column(children: children);
  }
}
