import 'dart:async';

import 'package:archiveme_mobile/features/archive/widgets/map_popup_card.dart';
import 'package:archiveme_mobile/features/map/entry_map.dart';
import 'package:archiveme_mobile/features/map/entry_map_view.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

const mapEmptyLocationsCopy =
    'No locations recorded yet. Turn on location tagging while recording to build your map.';

/// Pins for moments that have coordinates, clustered for low-accuracy places.
class MapView extends StatefulWidget {
  const MapView({
    required this.entries,
    this.onOpenEntry,
    this.locationPermissionDenied,
    super.key,
  });

  final List<JournalEntry> entries;
  final ValueChanged<String>? onOpenEntry;

  /// When set, skips the device permission check.
  final bool? locationPermissionDenied;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  var _denied = false;

  @override
  void initState() {
    super.initState();
    final supplied = widget.locationPermissionDenied;
    if (supplied != null) {
      _denied = supplied;
      return;
    }
    unawaited(_readPermission());
  }

  Future<void> _readPermission() async {
    try {
      final status = await Geolocator.checkPermission().timeout(
        const Duration(milliseconds: 400),
      );
      if (!mounted) return;
      if (status == LocationPermission.deniedForever) {
        setState(() => _denied = true);
      }
    } on Object {
      // The plugin is absent in widget tests, and a denied check must not throw.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pins = JournalMapClusterManager.cluster(widget.entries);
    final byId = {for (final entry in widget.entries) entry.id: entry};
    final showEmpty = pins.isEmpty || _denied;
    return Stack(
      children: [
        EntryMapView(
          pins: showEmpty ? const [] : pins,
          onPin: (pin) => _openPin(context, pin, byId),
        ),
        if (showEmpty)
          ColoredBox(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  mapEmptyLocationsCopy,
                  key: Key('map_empty_state'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openPin(
    BuildContext context,
    MapPin pin,
    Map<String, JournalEntry> byId,
  ) {
    final entries = [
      for (final moment in pin.entries)
        if (byId[moment.id] != null) byId[moment.id]!,
    ];
    if (entries.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        if (entries.length == 1) {
          return _sheet(context, entries.single);
        }
        return SafeArea(
          child: SizedBox(
            height: 360,
            child: ListView.builder(
              key: const Key('map_cluster_cards'),
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 280,
                  child: _sheet(context, entries[index], scroll: false),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _sheet(BuildContext context, JournalEntry entry, {bool scroll = true}) {
    final card = MapPopupCard(
      entry: entry,
      onViewEntry: widget.onOpenEntry == null
          ? null
          : () {
              Navigator.of(context).pop();
              widget.onOpenEntry!(entry.id);
            },
    );
    if (!scroll) return card;
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('map_place_card'),
        child: card,
      ),
    );
  }
}
