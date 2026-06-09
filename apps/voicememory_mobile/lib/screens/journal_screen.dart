import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/journal_entry.dart';
import '../design/empty_archive_experience.dart';
import '../features/timeline/timeline_entry_display.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/pushed_screen_shell.dart';
import '../widgets/timeline_sync_badge.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  var _loading = true;
  List<JournalEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    final peek = peekJournalEntriesSync(AppServices.instance.journalStore);
    if (isIntentionalEmptyArchive(peek)) {
      _entries = peek;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    final entries = await AppServices.instance.journalStore.loadAll();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Journal',
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh journal list',
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: const [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: IntentionalEmptyArchiveView(fillViewport: false),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = _entries[index];
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
                        '${e.createdAt.toLocal()} · ${e.durationSeconds}s',
                        style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                      ),
                      onTap: () => context.go('/entry/${e.id}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete local entry',
                        onPressed: () async {
                          await AppServices.instance.journalStore.delete(e.id);
                          if (context.mounted) _load();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
