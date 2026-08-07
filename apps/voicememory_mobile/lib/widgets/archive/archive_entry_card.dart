import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/journal_entry.dart';

class ArchiveEntryCard extends StatelessWidget {
  const ArchiveEntryCard({super.key, required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = entry.transcript.trim();
    final source = entry.durationSeconds > 0 ? 'Voice' : 'Text';
    final date = DateFormat.yMMMMd().add_jm().format(entry.createdAt.toLocal());
    return Semantics(
      button: true,
      label: '$source saved moment from $date',
      hint: 'Opens the original saved moment',
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    source,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    text.isEmpty ? 'Transcript processing…' : text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
