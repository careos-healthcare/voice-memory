import 'dart:async';

import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/entry/entry_photos.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Earlier years that share today's month and day.
class OnThisDayView extends StatelessWidget {
  const OnThisDayView({required this.entries, required this.now, super.key});

  final List<JournalEntry> entries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final matches = OnThisDayQuery.match(
      [for (final entry in entries) historyMomentFromEntry(entry)],
      now,
    );
    final years = <int>[];
    for (final entry in matches) {
      if (!years.contains(entry.createdAt.year)) {
        years.add(entry.createdAt.year);
      }
    }

    return ListView(
      key: const Key('on_this_day_view'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (matches.isEmpty)
          const ListTile(
            title: Text('Nothing from this day in earlier years.'),
          )
        else
          for (final year in years) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                _yearLabel(now.year - year, year),
                key: Key('on_this_day_year_$year'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final moment in matches)
              if (moment.createdAt.year == year) _OnThisDayCard(moment: moment),
          ],
      ],
    );
  }

  static String _yearLabel(int yearsAgo, int year) {
    final span = yearsAgo == 1 ? '1 Year Ago' : '$yearsAgo Years Ago';
    return '$span - $year';
  }
}

class _OnThisDayCard extends StatelessWidget {
  const _OnThisDayCard({required this.moment});

  final HistoryMoment moment;

  @override
  Widget build(BuildContext context) {
    final photo = moment.imagePaths.isEmpty ? null : moment.imagePaths.first;
    final audio = moment.audioPath?.trim();
    return Card(
      key: Key('on_this_day_${moment.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photo != null) ...[
              EntryPhotoThumbnail(path: photo, entryId: moment.id),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shortVerbatimQuote(moment.transcript, maxChars: 160)),
                  if (audio != null && audio.isNotEmpty)
                    _MomentPlayButton(entryId: moment.id, audioPath: audio),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentPlayButton extends StatefulWidget {
  const _MomentPlayButton({required this.entryId, required this.audioPath});

  final String entryId;
  final String audioPath;

  @override
  State<_MomentPlayButton> createState() => _MomentPlayButtonState();
}

class _MomentPlayButtonState extends State<_MomentPlayButton> {
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
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: Key('on_this_day_play_${widget.entryId}'),
      onPressed: () => unawaited(_play()),
      icon: const Icon(Icons.play_arrow, size: 18),
      label: const Text('Play'),
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
  );
}
