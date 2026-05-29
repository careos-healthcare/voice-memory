import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/sync_status.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/scaffold_shell.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AppServices.instance.journalStore.loadAll();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldShell(
      title: 'Journal',
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh list',
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder(
              future: AppServices.instance.journalStore.loadAll(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('${snapshot.error}'));
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No reflections yet.'),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => context.go('/record'),
                            child: const Text('Record first reflection'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    final preview = e.transcript.isEmpty
                        ? 'Untitled'
                        : e.transcript.split('\n').first;
                    return ListTile(
                      title: Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${e.createdAt.toLocal()} · ${e.durationSeconds}s · ${e.syncStatus.label}',
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
                );
              },
            ),
    );
  }
}
