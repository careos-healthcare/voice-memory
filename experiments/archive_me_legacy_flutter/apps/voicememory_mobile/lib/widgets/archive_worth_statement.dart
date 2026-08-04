import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/production_navigation.dart';
import '../models/journal_entry.dart';
import '../theme/app_theme.dart';

/// Archive worth line — mirrors web `ArchiveWorthStatement` (compact).
class ArchiveWorthStatement extends StatelessWidget {
  const ArchiveWorthStatement({
    super.key,
    required this.entries,
    this.onProtectArchive,
  });

  final List<JournalEntry> entries;
  final VoidCallback? onProtectArchive;

  int get _reflectionCount => entries.length;

  @override
  Widget build(BuildContext context) {
    if (_reflectionCount == 0) return const SizedBox.shrink();

    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Archive worth',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your archive would be hard to rebuild.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Your archive contains $_reflectionCount saved moment${_reflectionCount == 1 ? '' : 's'} on this device.',
              style: const TextStyle(color: AppTheme.muted, height: 1.45),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onProtectArchive != null)
                  FilledButton(
                    onPressed: onProtectArchive,
                    child: const Text('Protect this archive'),
                  ),
                if (ProductionNavigation.isNavRouteVisible('/export'))
                  OutlinedButton(
                    onPressed: () => context.push('/export'),
                    child: const Text('Export archive'),
                  ),
                OutlinedButton(
                  onPressed: () => context.push('/subscription'),
                  child: const Text('Keep tracking with Pro'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
