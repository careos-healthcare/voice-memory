import 'package:archiveme_mobile/features/history/history_browse.dart';

class MapPin {
  const MapPin({
    required this.latitude,
    required this.longitude,
    required this.entries,
  });

  final double latitude;
  final double longitude;
  final List<HistoryMoment> entries;

  String get label {
    final named = entries
        .map((entry) => entry.place?.trim() ?? '')
        .where((place) => place.isNotEmpty);
    if (named.isNotEmpty) return named.first;
    return 'Add a place to any moment';
  }
}

/// Groups nearby moments so one pin stands for a neighbourhood.
abstract final class EntryMapClusters {
  EntryMapClusters._();

  static List<MapPin> cluster(List<HistoryMoment> entries) {
    final groups = <String, List<HistoryMoment>>{};
    for (final entry in entries) {
      final latitude = entry.latitude;
      final longitude = entry.longitude;
      if (latitude == null || longitude == null) continue;
      final key =
          '${latitude.toStringAsFixed(1)},${longitude.toStringAsFixed(1)}';
      groups.putIfAbsent(key, () => []).add(entry);
    }
    return [
      for (final group in groups.values)
        MapPin(
          latitude: group.first.latitude!,
          longitude: group.first.longitude!,
          entries: group,
        ),
    ];
  }
}
