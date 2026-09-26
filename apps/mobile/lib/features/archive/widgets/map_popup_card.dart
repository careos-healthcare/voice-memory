import 'dart:async';

import 'package:archiveme_mobile/audio/audio_player_service.dart';
import 'package:archiveme_mobile/design/locale_date_format.dart';
import 'package:archiveme_mobile/features/archive/controllers/on_this_day_controller.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/entry/entry_photos.dart';
import 'package:flutter/material.dart';

/// Photo-first card for one mapped moment.
class MapPopupCard extends StatelessWidget {
  const MapPopupCard({
    required this.entry,
    required this.onViewEntry,
    this.onPlay,
    super.key,
  });

  final JournalEntry entry;
  final VoidCallback? onViewEntry;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final place = entry.display.locationLabel?.trim() ?? '';
    final photo = entry.images.isEmpty ? null : entry.images.first;
    final sentence = OnThisDayController.firstSentence(entry.transcript);
    final audio = entry.localAudioPath?.trim() ?? '';
    return Card(
      key: Key('map_popup_${entry.id}'),
      margin: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo != null)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: EntryPhotoThumbnail(
                path: photo,
                entryId: entry.id,
                fill: true,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleDateFormat.date(context, entry.createdAt),
                  key: Key('map_date_${entry.id}'),
                ),
                if (place.isNotEmpty) Text(place),
                const SizedBox(height: 8),
                Text(
                  sentence,
                  key: Key('map_sentence_${entry.id}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (audio.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      key: Key('map_play_${entry.id}'),
                      tooltip: 'Play',
                      onPressed: () {
                        final play = onPlay;
                        if (play != null) {
                          play();
                          return;
                        }
                        unawaited(AudioPlayerService().play(audio));
                      },
                      icon: const Icon(Icons.play_arrow),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: Key('map_open_${entry.id}'),
                    onPressed: onViewEntry,
                    child: const Text('View Entry'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
