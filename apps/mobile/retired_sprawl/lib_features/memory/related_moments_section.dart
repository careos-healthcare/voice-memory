import 'dart:async';

import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/design/locale_date_format.dart';
import 'package:archiveme_mobile/features/memory/entry_embedding_store.dart';
import 'package:archiveme_mobile/features/memory/related_entries_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Earlier moments that share the words of this entry.
class RelatedMomentsSection extends StatefulWidget {
  const RelatedMomentsSection({required this.entry, super.key});

  final JournalEntry entry;

  @override
  State<RelatedMomentsSection> createState() => _RelatedMomentsSectionState();
}

class _RelatedMomentsSectionState extends State<RelatedMomentsSection> {
  List<SimilarEntry> _matches = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!AppServices.isInitialized) return;
    try {
      final store = EntryEmbeddingStore(
        AppServices.instance.sqliteDatabase.database,
      );
      final entries = await AppServices.instance.journal.loadAll();
      final matches = await RelatedEntriesService(store).relatedTo(
        widget.entry,
        candidates: entries,
      );
      if (!mounted) return;
      setState(() => _matches = matches);
    } on Object {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_matches.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('entry_detail_related_moments'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Related moments',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ViewEvidenceInlineLink(
          entryIds: [for (final match in _matches) match.id],
          surface: 'entry_detail_related_moments',
          claimContext: 'Related moments',
        ),
        for (final match in _matches) ...[
          const SizedBox(height: 12),
          InkWell(
            key: Key('entry_detail_related_open_${match.id}'),
            onTap: () {
              final seconds = match.startSeconds ?? 0;
              final router = GoRouter.maybeOf(context);
              if (router == null) return;
              router.push('/entry/${match.id}?t=$seconds');
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(LocaleDateFormat.date(context, match.createdAt)),
                const SizedBox(height: 4),
                Text(match.quote ?? match.transcript.trim()),
              ],
            ),
          ),
          if (match.localAudioPath != null)
            _RelatedPlayButton(
              entryId: match.id,
              audioPath: match.localAudioPath!,
              startSeconds: match.startSeconds,
            ),
        ],
      ],
    );
  }
}

class _RelatedPlayButton extends StatefulWidget {
  const _RelatedPlayButton({
    required this.entryId,
    required this.audioPath,
    this.startSeconds,
  });

  final String entryId;
  final String audioPath;
  final int? startSeconds;

  @override
  State<_RelatedPlayButton> createState() => _RelatedPlayButtonState();
}

class _RelatedPlayButtonState extends State<_RelatedPlayButton> {
  AudioPlayer? _player;

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _play() async {
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.play(DeviceFileSource(widget.audioPath));
    final start = widget.startSeconds;
    if (start != null && start > 0) {
      await player.seek(Duration(seconds: start));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: Key('entry_detail_related_play_${widget.entryId}'),
        onPressed: () => unawaited(_play()),
        icon: const Icon(Icons.play_arrow, size: 18),
        label: const Text('Play'),
      ),
    );
  }
}
