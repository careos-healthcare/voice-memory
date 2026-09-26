import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// One saved moment placed on the map.
class JournalMapItem {
  const JournalMapItem(this.entry);

  final JournalEntry entry;

  double? get latitude => entry.display.latitude;

  double? get longitude => entry.display.longitude;

  bool get hasCoordinate => latitude != null && longitude != null;

  /// Identity for a low-accuracy fix. `LocationAccuracy.low` repeats this pair,
  /// so identical coordinates must share one pin.
  String? get identicalCoordinateKey {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return null;
    return '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
  }
}

class MapPin {
  const MapPin({
    required this.latitude,
    required this.longitude,
    required this.entries,
  });

  final double latitude;
  final double longitude;
  final List<HistoryMoment> entries;

  bool get isCluster => entries.length > 1;

  String get label {
    final named = entries
        .map((entry) => entry.place?.trim() ?? '')
        .where((place) => place.isNotEmpty);
    if (named.isNotEmpty) return named.first;
    return 'Add a place to any moment';
  }
}

/// Coordinates shown on the map. Two decimal places is about a kilometre.
abstract final class EntryMapCoordinates {
  EntryMapCoordinates._();

  static double coarse(double value) => double.parse(value.toStringAsFixed(2));
}

/// Groups low-accuracy fixes that share a coordinate, then a nearby cell.
abstract final class EntryMapClusters {
  EntryMapClusters._();

  static List<MapPin> cluster(List<HistoryMoment> entries) {
    final groups = <String, List<HistoryMoment>>{};
    for (final entry in entries) {
      final latitude = entry.latitude;
      final longitude = entry.longitude;
      if (latitude == null || longitude == null) continue;
      groups.putIfAbsent(_cellKey(latitude, longitude), () => []).add(entry);
    }
    return [
      for (final group in groups.values)
        MapPin(
          latitude: EntryMapCoordinates.coarse(group.first.latitude!),
          longitude: EntryMapCoordinates.coarse(group.first.longitude!),
          entries: group,
        ),
    ];
  }

  /// Identical coordinates share a cell. A tenth of a degree also merges
  /// neighbouring low-accuracy fixes so pins do not stack.
  static String _cellKey(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(1)},${longitude.toStringAsFixed(1)}';
  }
}

/// Cluster manager for journal rows. Identical coordinates become one pin.
abstract final class JournalMapClusterManager {
  JournalMapClusterManager._();

  static List<MapPin> cluster(List<JournalEntry> entries) {
    return EntryMapClusters.cluster([
      for (final item in entries.map(JournalMapItem.new))
        if (item.identicalCoordinateKey != null)
          HistoryMoment(
            id: item.entry.id,
            createdAt: item.entry.createdAt,
            transcript: item.entry.transcript,
            place: item.entry.display.locationLabel,
            latitude: item.latitude,
            longitude: item.longitude,
            imagePaths: item.entry.images,
          ),
    ]);
  }
}
