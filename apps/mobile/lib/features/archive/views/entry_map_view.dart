import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archiveme_mobile/features/map/entry_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

const mapEmptyPlacesCopy = 'Turn on places to see where your moments happened.';

/// OpenStreetMap with soft area markers. Clusters open a list instead of zooming.
class EntryMapView extends StatelessWidget {
  const EntryMapView({
    required this.pins,
    required this.onPin,
    this.onCluster,
    super.key,
  });

  final List<MapPin> pins;
  final ValueChanged<MapPin> onPin;
  final ValueChanged<List<MapPin>>? onCluster;

  @override
  Widget build(BuildContext context) {
    final points = [
      for (final pin in pins) LatLng(pin.latitude, pin.longitude),
    ];
    final empty = points.isEmpty;
    final primary = Theme.of(context).colorScheme.primary;
    final markers = [for (final pin in pins) _marker(pin, primary)];
    final byKey = {
      for (final pin in pins) ValueKey(pin.entries.first.id): pin,
    };
    return Stack(
      key: const Key('entry_map_view'),
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: empty ? const LatLng(20, 0) : points.first,
            initialZoom: empty ? 2 : 4,
            initialCameraFit: empty
                ? null
                : CameraFit.bounds(
                    bounds: _bounds(points),
                    padding: const EdgeInsets.all(48),
                    maxZoom: 11,
                  ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.voicememory.mobile',
              tileDisplay: const TileDisplay.instantaneous(),
              tileProvider: _tiles(),
            ),
            if (markers.isNotEmpty)
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 48,
                  size: const Size(56, 56),
                  zoomToBoundsOnClick: false,
                  spiderfyCluster: false,
                  centerMarkerOnClick: false,
                  markerChildBehavior: true,
                  markers: markers,
                  builder: (context, grouped) => _AreaBadge(
                    color: primary,
                    count: grouped.length,
                  ),
                  onMarkerTap: (marker) {
                    final pin = byKey[marker.key];
                    if (pin != null) onPin(pin);
                  },
                  onClusterTap: (cluster) {
                    final grouped = [
                      for (final marker in cluster.mapMarkers)
                        if (byKey[marker.key] != null) byKey[marker.key]!,
                    ];
                    if (grouped.isEmpty) return;
                    final open = onCluster;
                    if (open != null) {
                      open(grouped);
                    } else if (grouped.length == 1) {
                      onPin(grouped.first);
                    }
                  },
                ),
              ),
          ],
        ),
        if (empty)
          ColoredBox(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  mapEmptyPlacesCopy,
                  key: Key('map_empty_state'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Marker _marker(MapPin pin, Color primary) {
    return Marker(
      key: ValueKey(pin.entries.first.id),
      point: LatLng(pin.latitude, pin.longitude),
      width: 56,
      height: 56,
      child: GestureDetector(
        onTap: () => onPin(pin),
        child: _AreaBadge(
          color: primary,
          count: pin.isCluster ? pin.entries.length : null,
          areaKey: Key('map_area_${pin.latitude}_${pin.longitude}'),
        ),
      ),
    );
  }

  static LatLngBounds _bounds(List<LatLng> points) {
    if (points.length == 1) {
      final point = points.first;
      return LatLngBounds(
        LatLng(point.latitude - 0.15, point.longitude - 0.15),
        LatLng(point.latitude + 0.15, point.longitude + 0.15),
      );
    }
    return LatLngBounds.fromPoints(points);
  }

  static TileProvider _tiles() {
    if (!kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true') {
      return _QuietTileProvider();
    }
    return NetworkTileProvider();
  }
}

class _AreaBadge extends StatelessWidget {
  const _AreaBadge({required this.color, this.count, this.areaKey});

  final Color color;
  final int? count;
  final Key? areaKey;

  @override
  Widget build(BuildContext context) {
    final clustered = count != null && count! > 1;
    return Center(
      child: Container(
        key: clustered ? Key('map_cluster_$count') : areaKey,
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.35),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 2),
        ),
        child: clustered
            ? Text(
                '$count',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    );
  }
}

class _QuietTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return const _BlankTileImage();
  }
}

class _BlankTileImage extends ImageProvider<_BlankTileImage> {
  const _BlankTileImage();

  @override
  Future<_BlankTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _BlankTileImage key,
    ImageDecoderCallback decode,
  ) {
    final completer = Completer<ImageInfo>();
    ui.decodeImageFromPixels(
      Uint8List.fromList(const [0, 0, 0, 0]),
      1,
      1,
      ui.PixelFormat.rgba8888,
      (image) => completer.complete(ImageInfo(image: image)),
    );
    return OneFrameImageStreamCompleter(completer.future);
  }

  @override
  bool operator ==(Object other) => other is _BlankTileImage;

  @override
  int get hashCode => 0;
}
