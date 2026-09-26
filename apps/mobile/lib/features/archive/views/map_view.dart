import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/design/locale_date_format.dart';
import 'package:archiveme_mobile/features/archive/views/on_this_day_view.dart';
import 'package:archiveme_mobile/features/map/entry_map.dart';
import 'package:archiveme_mobile/features/map/entry_map_view.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/entry/entry_photos.dart';
import 'package:flutter/material.dart';

/// Pins for moments that have coordinates, clustered for low-accuracy places.
class MapView extends StatelessWidget {
  const MapView({required this.entries, this.onOpenEntry, super.key});

  final List<JournalEntry> entries;
  final ValueChanged<String>? onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final pins = EntryMapClusters.cluster([
      for (final entry in entries) historyMomentFromEntry(entry),
    ]);
    if (pins.isEmpty) {
      return const Center(
        child: Text('No places on these moments yet.'),
      );
    }
    return EntryMapView(
      pins: pins,
      onPin: (pin) {
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => _PinCard(pin: pin, onOpenEntry: onOpenEntry),
        );
      },
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({required this.pin, required this.onOpenEntry});

  final MapPin pin;
  final ValueChanged<String>? onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        key: const Key('map_place_card'),
        children: [
          ListTile(title: Text(pin.label)),
          for (final entry in pin.entries)
            ListTile(
              key: Key('map_entry_${entry.id}'),
              leading: entry.imagePaths.isEmpty
                  ? null
                  : EntryPhotoThumbnail(
                      path: entry.imagePaths.first,
                      entryId: entry.id,
                    ),
              title: Text(LocaleDateFormat.date(context, entry.createdAt)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(shortVerbatimQuote(entry.transcript, maxChars: 120)),
                  TextButton(
                    key: Key('map_open_${entry.id}'),
                    onPressed: onOpenEntry == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            onOpenEntry!(entry.id);
                          },
                    child: const Text('View entry'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
