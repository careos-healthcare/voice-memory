import 'dart:async';

import 'package:archiveme_mobile/features/archive/widgets/map_popup_card.dart';
import 'package:archiveme_mobile/features/map/entry_map.dart';
import 'package:archiveme_mobile/features/archive/views/entry_map_view.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Pins for moments that have coordinates, clustered for low-accuracy places.
class MapView extends StatefulWidget {
  const MapView({
    required this.entries,
    this.onOpenEntry,
    this.onPlay,
    this.onOpenPlaces,
    this.locationPermissionDenied,
    super.key,
  });

  final List<JournalEntry> entries;
  final ValueChanged<String>? onOpenEntry;
  final ValueChanged<JournalEntry>? onPlay;

  /// Opens the location setting. Defaults to the system app settings.
  final VoidCallback? onOpenPlaces;

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
          onPin: (pin) => _openPins(context, [pin], byId),
          onCluster: (grouped) => _openPins(context, grouped, byId),
          onOpenPlaces: widget.onOpenPlaces ??
              () => unawaited(Geolocator.openAppSettings()),
        ),
      ],
    );
  }

  void _openPins(
    BuildContext context,
    List<MapPin> pins,
    Map<String, JournalEntry> byId,
  ) {
    final entries = [
      for (final pin in pins)
        for (final moment in pin.entries)
          if (byId[moment.id] != null) byId[moment.id]!,
    ];
    if (entries.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: entries.length == 1 ? null : 420,
            child: ListView(
              key: Key(
                entries.length > 1 ? 'map_cluster_cards' : 'map_place_card',
              ),
              shrinkWrap: entries.length == 1,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              children: [
                for (final entry in entries)
                  MapPopupCard(
                    entry: entry,
                    onPlay: widget.onPlay == null
                        ? null
                        : () => widget.onPlay!(entry),
                    onViewEntry: widget.onOpenEntry == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onOpenEntry!(entry.id);
                          },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
