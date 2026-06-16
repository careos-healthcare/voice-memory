import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/timeline/timeline_entry_display.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../widgets/timeline_sync_badge.dart';
import '../theme/app_theme.dart';
import '../features/archive_movement/archive_movement.dart';
import '../widgets/archive_movement_card.dart';
import '../widgets/archive_value_banner.dart';
import '../widgets/reflection_value_ladder.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<JournalEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await AppServices.instance.journal.loadAll();
    if (mounted) setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Memory', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Your archive on this device — patterns may strengthen as you add reflections.',
            style: TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 16),
          if (entries.isNotEmpty)
            ArchiveMovementCard(
              update: ArchiveMovementEngine.build(
                entries,
                newEntryId: entries.last.id,
              ),
            ),
          if (entries.isNotEmpty) const SizedBox(height: 12),
          ArchiveValueBanner(entries: entries),
          ReflectionValueLadder(entries: entries),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => context.push('/journal'),
                child: const Text('All reflections'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => context.push('/blind-spots'),
                child: const Text('Pattern review'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Text(
              'No reflections yet. Record your first on the Record tab.',
            )
          else
            ...entries.take(12).map((e) {
              final badge = timelineSyncBadgeLabel(e.syncStatus);
              return ListTile(
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        timelineEntryTitle(e),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      TimelineSyncBadge(label: badge),
                    ],
                  ],
                ),
                subtitle: Text(
                  e.createdAt.toLocal().toString().split('.').first,
                ),
                onTap: () => context.push('/entry/${e.id}'),
              );
            }),
        ],
      ),
    );
  }
}
