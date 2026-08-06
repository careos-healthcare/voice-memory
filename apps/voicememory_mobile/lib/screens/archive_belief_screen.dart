import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api/api_exceptions.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/archive/archive_search_field.dart';
import '../widgets/archive/archive_verified_changes_section.dart';

/// Archive: the user's original saved moments, plus verified changes when the
/// canonical proof pipeline admits one. See `docs/ARCHIVE_SCREEN_SPEC_V1.md`.
class ArchiveBeliefScreen extends StatefulWidget {
  const ArchiveBeliefScreen({super.key});

  @override
  State<ArchiveBeliefScreen> createState() => _ArchiveBeliefScreenState();
}

enum _ArchiveLoadState { loading, loaded, error, offline }

class _ArchiveBeliefScreenState extends State<ArchiveBeliefScreen> {
  List<JournalEntry>? _entries;
  _ArchiveLoadState _state = _ArchiveLoadState.loading;
  String _query = '';

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
        _state = _ArchiveLoadState.loaded;
      });
    } on SocketException {
      if (!mounted) return;
      setState(() => _state = _ArchiveLoadState.offline);
    } on NetworkOfflineException {
      if (!mounted) return;
      setState(() => _state = _ArchiveLoadState.offline);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _state = _ArchiveLoadState.offline);
    } on Object {
      if (!mounted) return;
      setState(() => _state = _ArchiveLoadState.error);
    }
  }

  Future<void> _open(JournalEntry entry) async {
    await context.push('/entry/${entry.id}');
    await _reload();
  }

  List<JournalEntry> _filtered(List<JournalEntry> entries) {
    if (_query.isEmpty) return entries;
    final needle = _query.toLowerCase();
    return entries
        .where((entry) => entry.transcript.toLowerCase().contains(needle))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _entries;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
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
              if (_state == _ArchiveLoadState.offline) ...[
                const SizedBox(height: 12),
                _StatusBanner(
                  key: const Key('archive_offline_banner'),
                  icon: Icons.cloud_off_outlined,
                  message:
                      "You're offline. Your saved moments are stored on this "
                      'device, so they are still shown below.',
                ),
              ] else if (_state == _ArchiveLoadState.error) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Your archive could not be opened right now.',
                    key: const Key('archive_error_text'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (entries == null)
                const Center(
                  key: Key('archive_loading_indicator'),
                  child: CircularProgressIndicator(),
                )
              else if (entries.isEmpty)
                _EmptyArchive(onCapture: () => context.go('/record'))
              else ...[
                if (entries.length > 1) ...[
                  ArchiveSearchField(
                    onQueryChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 16),
                ],
                ArchiveVerifiedChangesSection(entries: entries),
                Text('Original moments', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_filtered(entries).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No saved moments match "$_query".',
                      key: const Key('archive_search_no_results'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                else
                  for (final entry in _filtered(entries))
                    _entryCard(context, entry),
              ],
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 18, color: AppColors.textMuted),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
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
    key: const Key('archive_tab_entry_state_empty'),
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
