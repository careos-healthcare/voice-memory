import 'package:flutter/material.dart';

import '../models/journal_entry.dart';
import '../theme/app_theme.dart';

/// Top evidence quotes on device — compact locker (no new analysis).
class EvidenceLockerCompact extends StatelessWidget {
  const EvidenceLockerCompact({super.key, required this.entries});

  final List<JournalEntry> entries;

  List<String> get _topQuotes {
    final lines = <String>[];
    for (final e in entries) {
      final t = e.transcript.trim();
      if (t.length < 24) continue;
      lines.add(t.length > 120 ? '${t.substring(0, 120)}…' : t);
      if (lines.length >= 5) break;
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final quotes = _topQuotes;
    if (quotes.isEmpty) return const SizedBox.shrink();

    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evidence locker',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'These are the pieces of evidence your archive would lose.',
              style: TextStyle(color: AppTheme.muted, height: 1.45, fontSize: 13),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < quotes.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('“${quotes[i]}”', style: const TextStyle(height: 1.4)),
              ),
          ],
        ),
      ),
    );
  }
}
