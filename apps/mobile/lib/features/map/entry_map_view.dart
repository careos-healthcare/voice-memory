import 'package:archiveme_mobile/features/map/entry_map.dart';
import 'package:flutter/material.dart';

class EntryMapView extends StatelessWidget {
  const EntryMapView({required this.pins, required this.onPin, super.key});

  final List<MapPin> pins;
  final ValueChanged<MapPin> onPin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('entry_map_view'),
      children: [
        for (final pin in pins)
          ListTile(
            key: Key('map_pin_${pin.latitude}_${pin.longitude}'),
            title: Text(pin.label),
            subtitle: Text('${pin.entries.length} moments'),
            onTap: () => onPin(pin),
          ),
      ],
    );
  }
}
