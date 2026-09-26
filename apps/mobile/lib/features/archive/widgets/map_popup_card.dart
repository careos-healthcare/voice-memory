import 'package:archiveme_mobile/design/locale_date_format.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/entry/entry_photos.dart';
import 'package:flutter/material.dart';

/// Photo-first card for one mapped moment.
class MapPopupCard extends StatelessWidget {
  const MapPopupCard({
    required this.entry,
    required this.onViewEntry,
    super.key,
  });

  final JournalEntry entry;
  final VoidCallback? onViewEntry;

  @override
  Widget build(BuildContext context) {
    final place = entry.display.locationLabel?.trim() ?? '';
    final photo = entry.images.isEmpty ? null : entry.images.first;
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
                Text(LocaleDateFormat.date(context, entry.createdAt)),
                if (place.isNotEmpty) Text(place),
                const SizedBox(height: 8),
                Text(
                  entry.transcript.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
