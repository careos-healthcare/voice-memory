import 'package:archiveme_mobile/features/map/entry_map.dart';
import 'package:flutter/material.dart';

class EntryMapView extends StatelessWidget {
  const EntryMapView({required this.pins, required this.onPin, super.key});

  final List<MapPin> pins;
  final ValueChanged<MapPin> onPin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const Key('entry_map_view'),
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 360.0;
        final bounds = _MapBounds.fromPins(pins);
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _EntryMapPainter(
                    pins: pins,
                    bounds: bounds,
                    land: Theme.of(context).colorScheme.surfaceContainerHighest,
                    water: Theme.of(context).colorScheme.primaryContainer,
                    pinColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              for (final pin in pins)
                Positioned(
                  left: bounds.x(pin.longitude, width) - 18,
                  top: bounds.y(pin.latitude, height) - 18,
                  child: IconButton(
                    key: Key('map_pin_${pin.latitude}_${pin.longitude}'),
                    tooltip: pin.isCluster
                        ? '${pin.entries.length} moments'
                        : pin.label,
                    onPressed: () => onPin(pin),
                    icon: pin.isCluster
                        ? CircleAvatar(
                            key: Key('map_cluster_${pin.entries.length}'),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            child: Text('${pin.entries.length}'),
                          )
                        : const Icon(Icons.place),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MapBounds {
  const _MapBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  factory _MapBounds.fromPins(List<MapPin> pins) {
    if (pins.isEmpty) {
      return const _MapBounds(minLat: -10, maxLat: 10, minLng: -10, maxLng: 10);
    }
    var minLat = pins.first.latitude;
    var maxLat = pins.first.latitude;
    var minLng = pins.first.longitude;
    var maxLng = pins.first.longitude;
    for (final pin in pins) {
      if (pin.latitude < minLat) minLat = pin.latitude;
      if (pin.latitude > maxLat) maxLat = pin.latitude;
      if (pin.longitude < minLng) minLng = pin.longitude;
      if (pin.longitude > maxLng) maxLng = pin.longitude;
    }
    if (minLat == maxLat) {
      minLat -= 0.2;
      maxLat += 0.2;
    }
    if (minLng == maxLng) {
      minLng -= 0.2;
      maxLng += 0.2;
    }
    return _MapBounds(minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
  }

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  double x(double longitude, double width) {
    final span = maxLng - minLng;
    return ((longitude - minLng) / span) * (width - 48) + 24;
  }

  double y(double latitude, double height) {
    final span = maxLat - minLat;
    return (1 - ((latitude - minLat) / span)) * (height - 48) + 24;
  }
}

class _EntryMapPainter extends CustomPainter {
  const _EntryMapPainter({
    required this.pins,
    required this.bounds,
    required this.land,
    required this.water,
    required this.pinColor,
  });

  final List<MapPin> pins;
  final _MapBounds bounds;
  final Color land;
  final Color water;
  final Color pinColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = water);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(16, 16, size.width - 32, size.height - 32),
        const Radius.circular(18),
      ),
      Paint()..color = land,
    );
    final paint = Paint()..color = pinColor;
    for (final pin in pins) {
      canvas.drawCircle(
        Offset(bounds.x(pin.longitude, size.width), bounds.y(pin.latitude, size.height)),
        6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EntryMapPainter oldDelegate) =>
      oldDelegate.pins != pins;
}
