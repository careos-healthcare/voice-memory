import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple;
import 'package:archiveme_mobile/features/map/entry_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const mapEmptyPlacesCopy = 'Turn on places to see where your moments happened.';

/// Which tile source [EntryMapWidget] draws.
enum EntryMapPlatform { apple, openStreetMap }

/// Apple Maps on iPhone. OpenStreetMap everywhere else.
abstract final class EntryMapPlatforms {
  EntryMapPlatforms._();

  static EntryMapPlatform host() {
    if (!kIsWeb && Platform.isIOS) return EntryMapPlatform.apple;
    return EntryMapPlatform.openStreetMap;
  }
}

/// One map surface. iOS uses MapKit. Android uses OpenStreetMap tiles.
class EntryMapWidget extends StatelessWidget {
  const EntryMapWidget({
    required this.pins,
    required this.onPin,
    this.onCluster,
    this.platform,
    super.key,
  });

  final List<MapPin> pins;
  final ValueChanged<MapPin> onPin;
  final ValueChanged<List<MapPin>>? onCluster;

  /// Overrides the host choice. Widget tests stay on OpenStreetMap.
  final EntryMapPlatform? platform;

  @override
  Widget build(BuildContext context) {
    final choice = platform ?? EntryMapPlatforms.host();
    if (choice == EntryMapPlatform.apple) {
      return _AppleEntryMap(
        pins: pins,
        onOpen: _open,
      );
    }
    return _OsmEntryMap(
      pins: pins,
      onOpen: _open,
    );
  }

  void _open(MapPin pin) {
    if (pin.isCluster) {
      final open = onCluster;
      if (open != null) {
        open([pin]);
        return;
      }
    }
    onPin(pin);
  }
}

/// Clustered pins on a real map, with a places prompt when nothing is located.
class EntryMapView extends StatelessWidget {
  const EntryMapView({
    required this.pins,
    required this.onPin,
    this.onCluster,
    this.onOpenPlaces,
    this.platform,
    super.key,
  });

  final List<MapPin> pins;
  final ValueChanged<MapPin> onPin;
  final ValueChanged<List<MapPin>>? onCluster;
  final VoidCallback? onOpenPlaces;
  final EntryMapPlatform? platform;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const Key('entry_map_view'),
      children: [
        EntryMapWidget(
          pins: pins,
          onPin: onPin,
          onCluster: onCluster,
          platform: platform,
        ),
        if (pins.isEmpty)
          ColoredBox(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: TextButton(
                  key: const Key('map_empty_location_link'),
                  onPressed: onOpenPlaces,
                  child: const Text(
                    mapEmptyPlacesCopy,
                    key: Key('map_empty_state'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OsmEntryMap extends StatelessWidget {
  const _OsmEntryMap({required this.pins, required this.onOpen});

  final List<MapPin> pins;
  final ValueChanged<MapPin> onOpen;

  @override
  Widget build(BuildContext context) {
    final points = [
      for (final pin in pins) LatLng(pin.latitude, pin.longitude),
    ];
    final empty = points.isEmpty;
    final primary = Theme.of(context).colorScheme.primary;
    return FlutterMap(
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
        MarkerLayer(
          markers: [
            for (final pin in pins) _marker(pin, primary),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap contributors'),
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
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => onOpen(pin),
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

class _AppleEntryMap extends StatefulWidget {
  const _AppleEntryMap({required this.pins, required this.onOpen});

  final List<MapPin> pins;
  final ValueChanged<MapPin> onOpen;

  @override
  State<_AppleEntryMap> createState() => _AppleEntryMapState();
}

class _AppleEntryMapState extends State<_AppleEntryMap> {
  final _icons = <int, apple.BitmapDescriptor>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadIcons());
  }

  Future<void> _loadIcons() async {
    final counts = <int>{
      for (final pin in widget.pins) pin.isCluster ? pin.entries.length : 0,
    };
    for (final count in counts) {
      final bytes = await _badgePng(count);
      _icons[count] = apple.BitmapDescriptor.fromBytes(bytes);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.pins.isEmpty ? null : widget.pins.first;
    return apple.AppleMap(
      initialCameraPosition: apple.CameraPosition(
        target: apple.LatLng(first?.latitude ?? 20, first?.longitude ?? 0),
        zoom: widget.pins.isEmpty ? 2 : 4,
      ),
      rotateGesturesEnabled: false,
      annotations: {
        for (final pin in widget.pins)
          apple.Annotation(
            annotationId: apple.AnnotationId(pin.entries.first.id),
            position: apple.LatLng(pin.latitude, pin.longitude),
            anchor: const Offset(0.5, 0.5),
            icon: _icons[pin.isCluster ? pin.entries.length : 0] ??
                apple.BitmapDescriptor.markerAnnotation,
            onTap: () => widget.onOpen(pin),
          ),
      },
    );
  }
}

Future<Uint8List> _badgePng(int count) async {
  const size = 64.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawCircle(
    const Offset(32, 32),
    28,
    Paint()..color = const Color(0xFF5C6B4A),
  );
  if (count > 1) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$count',
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(32 - painter.width / 2, 32 - painter.height / 2),
    );
  }
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
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
