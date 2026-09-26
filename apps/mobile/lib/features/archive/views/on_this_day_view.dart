import 'dart:async';

import 'package:archiveme_mobile/audio/audio_player_service.dart';
import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/features/archive/controllers/on_this_day_controller.dart';
import 'package:archiveme_mobile/features/archive/views/on_this_day_section.dart';
import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:archiveme_mobile/features/media/services/image_processor_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/entry/entry_photos.dart';
import 'package:flutter/material.dart';

/// Earlier years that share today's month and day.
class OnThisDayView extends StatefulWidget {
  const OnThisDayView({
    required this.entries,
    required this.now,
    this.onSilence,
    this.audioPlayer,
    super.key,
  });

  final List<JournalEntry> entries;
  final DateTime now;
  final Future<void> Function(String entryId)? onSilence;
  final AudioPlayerService? audioPlayer;

  @override
  State<OnThisDayView> createState() => _OnThisDayViewState();
}

class _OnThisDayViewState extends State<OnThisDayView> {
  final _hidden = <String>{};
  AudioPlayerService? _player;

  AudioPlayerService get _audio =>
      widget.audioPlayer ?? (_player ??= AudioPlayerService());

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _hide(JournalEntry entry) async {
    final hide = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('on_this_day_hide_dialog'),
        title: const Text('Hide this memory?'),
        content: const Text(
          'Hide this memory? It will no longer appear in On This Day.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('on_this_day_hide_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hide'),
          ),
        ],
      ),
    );
    if (hide != true || !mounted) return;
    await widget.onSilence?.call(entry.id);
    if (!mounted) return;
    setState(() => _hidden.add(entry.id));
  }

  @override
  Widget build(BuildContext context) {
    final groups = OnThisDayController.group(
      entries: widget.entries,
      today: widget.now,
      silencedIds: _hidden,
    );
    if (groups.isEmpty) {
      return ListView(
        key: const Key('on_this_day_view'),
        children: const [OnThisDayEmptySection()],
      );
    }

    return ListView(
      key: const Key('on_this_day_view'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final label in groups.keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              label,
              key: Key('on_this_day_label_$label'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final entry in groups[label]!)
            _OnThisDayCard(
              entry: entry,
              onHide: () => unawaited(_hide(entry)),
              onPlay: () {
                final url = entry.audioUrl;
                if (url == null || url.trim().isEmpty) return;
                unawaited(_audio.play(url));
              },
            ),
        ],
      ],
    );
  }
}

class _OnThisDayCard extends StatelessWidget {
  const _OnThisDayCard({
    required this.entry,
    required this.onHide,
    required this.onPlay,
  });

  final JournalEntry entry;
  final VoidCallback onHide;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final photo = entry.images.isEmpty ? null : entry.images.first;
    final audio = entry.audioUrl?.trim();
    return Card(
      key: Key('on_this_day_${entry.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Spacer(),
                PopupMenuButton<String>(
                  key: Key('on_this_day_menu_${entry.id}'),
                  tooltip: 'More',
                  onSelected: (_) => onHide(),
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'hide',
                      child: Text("Don't show me this again"),
                    ),
                  ],
                ),
              ],
            ),
            if (photo != null) ...[
              EntryPhotoThumbnail(
                path: ImageProcessorService.previewPath(photo),
                entryId: entry.id,
              ),
              const SizedBox(height: 12),
            ],
            Text(shortVerbatimQuote(entry.transcript, maxChars: 160)),
            if (audio != null && audio.isNotEmpty)
              TextButton.icon(
                key: Key('on_this_day_play_${entry.id}'),
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Play'),
              ),
          ],
        ),
      ),
    );
  }
}

HistoryMoment historyMomentFromEntry(JournalEntry entry) {
  final mood = entry.reflection.mood.trim();
  final place = entry.display.locationLabel?.trim();
  final audio = entry.localAudioPath?.trim();
  return HistoryMoment(
    id: entry.id,
    createdAt: entry.createdAt,
    transcript: entry.transcript,
    mood: mood.isEmpty ? null : mood,
    place: place == null || place.isEmpty ? null : place,
    latitude: entry.display.latitude,
    longitude: entry.display.longitude,
    imagePaths: entry.images,
    audioPath: audio == null || audio.isEmpty ? null : audio,
    durationSeconds: entry.durationSeconds,
  );
}
