import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/journal_entry.dart';
import '../services/app_services.dart';

/// V1 Archive: the user's original saved moments, without interpretation.
class ArchiveBeliefScreen extends StatefulWidget {
  const ArchiveBeliefScreen({super.key});

  @override
  State<ArchiveBeliefScreen> createState() => _ArchiveBeliefScreenState();
}

class _ArchiveBeliefScreenState extends State<ArchiveBeliefScreen> {
  List<JournalEntry>? _entries;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final entries = (await AppServices.instance.journalStore.loadAll())
          .toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _error = null;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'Your archive could not be opened right now.');
    }
  }

  Future<void> _open(JournalEntry entry) async {
    await context.push('/entry/${entry.id}');
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text(
                'Your original recordings, typed moments and transcripts.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (entries == null)
                const Center(child: CircularProgressIndicator())
              else if (entries.isEmpty)
                _EmptyArchive(onCapture: () => context.go('/record'))
              else
                for (final entry in entries) _entryCard(context, entry),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entryCard(BuildContext context, JournalEntry entry) {
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
          onTap: () => _open(entry),
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
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive({required this.onCapture});

  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your first saved moment will appear here.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('Record or type something real. You can edit it later.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onCapture, child: const Text('Go to Record')),
        ],
      ),
    ),
  );
}
