import 'package:archiveme_mobile/features/metadata/ambient_metadata.dart';
import 'package:archiveme_mobile/features/security/private_vault_gate.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_021_ambient_metadata.dart';
import 'package:sqflite/sqflite.dart';

/// One journal row used by the timeline heatmap and map.
class TimelineMapEntry {
  const TimelineMapEntry({
    required this.id,
    required this.createdAt,
    required this.transcript,
    required this.sentiment,
    this.latitude,
    this.longitude,
  });

  final String id;
  final DateTime createdAt;
  final String transcript;
  final double sentiment;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get preview {
    final words = transcript.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (words.length <= 80) return words;
    return '${words.substring(0, 80)}…';
  }
}

/// Counts and average tone for one local calendar day.
class DayStats {
  const DayStats({
    required this.day,
    required this.count,
    required this.meanSentiment,
    required this.entryIds,
  });

  final DateTime day;
  final int count;
  final double meanSentiment;
  final List<String> entryIds;
}

/// Nearby moments sharing one map pin.
class MapCluster {
  const MapCluster({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.entryIds,
    required this.meanSentiment,
  });

  final String id;
  final double latitude;
  final double longitude;
  final List<String> entryIds;
  final double meanSentiment;
}

/// Which part of the timeline is narrowing the list.
class TimelineSelection {
  const TimelineSelection({this.day, this.clusterId});

  final DateTime? day;
  final String? clusterId;

  static const none = TimelineSelection();
}

/// Calendar cells, map clusters, and the filtered moment list.
class TimelineHeatmapIndex {
  const TimelineHeatmapIndex({
    required this.entries,
    required this.days,
    required this.clusters,
  });

  factory TimelineHeatmapIndex.fromEntries(List<TimelineMapEntry> entries) {
    final grouped = <String, List<TimelineMapEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(dayKey(entry.createdAt), () => []).add(entry);
    }
    final days = <String, DayStats>{
      for (final group in grouped.entries)
        group.key: DayStats(
          day: dateOnly(group.value.first.createdAt),
          count: group.value.length,
          meanSentiment: _mean(group.value.map((entry) => entry.sentiment)),
          entryIds: [for (final entry in group.value) entry.id],
        ),
    };
    return TimelineHeatmapIndex(
      entries: entries,
      days: days,
      clusters: clusterEntries(entries),
    );
  }

  final List<TimelineMapEntry> entries;
  final Map<String, DayStats> days;
  final List<MapCluster> clusters;

  List<TimelineMapEntry> matching(TimelineSelection selection) {
    if (selection.day != null) {
      final key = dayKey(selection.day!);
      return [
        for (final entry in entries)
          if (dayKey(entry.createdAt) == key) entry,
      ];
    }
    if (selection.clusterId != null) {
      MapCluster? cluster;
      for (final item in clusters) {
        if (item.id == selection.clusterId) cluster = item;
      }
      if (cluster == null) return const [];
      final ids = cluster.entryIds.toSet();
      return [
        for (final entry in entries)
          if (ids.contains(entry.id)) entry,
      ];
    }
    return entries;
  }
}

/// Local calendar date, ignoring the clock time.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// `yyyy-mm-dd` key for [value] in local time.
String dayKey(DateTime value) {
  final day = dateOnly(value);
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

/// Word tone from -1 to 1. Empty text stays at 0.
double entrySentiment(String text) {
  final tokens = text
      .toLowerCase()
      .split(RegExp('[^a-z]+'))
      .where((token) => token.isNotEmpty);
  var total = 0;
  var counted = 0;
  for (final token in tokens) {
    counted += 1;
    if (_positive.contains(token)) total += 1;
    if (_negative.contains(token)) total -= 1;
  }
  if (counted == 0) return 0;
  return (total / counted).clamp(-1, 1).toDouble();
}

/// Groups coordinates onto a 0.05 degree grid.
List<MapCluster> clusterEntries(List<TimelineMapEntry> entries) {
  final groups = <String, List<TimelineMapEntry>>{};
  for (final entry in entries) {
    final latitude = entry.latitude;
    final longitude = entry.longitude;
    if (latitude == null || longitude == null) continue;
    final key = clusterId(latitude, longitude);
    groups.putIfAbsent(key, () => []).add(entry);
  }
  final clusters = <MapCluster>[];
  for (final group in groups.entries) {
    final rows = group.value;
    clusters.add(
      MapCluster(
        id: group.key,
        latitude: _mean(rows.map((entry) => entry.latitude!)),
        longitude: _mean(rows.map((entry) => entry.longitude!)),
        entryIds: [for (final entry in rows) entry.id],
        meanSentiment: _mean(rows.map((entry) => entry.sentiment)),
      ),
    );
  }
  clusters.sort((a, b) => a.id.compareTo(b.id));
  return clusters;
}

/// Stable pin id for a coordinate bucket.
String clusterId(double latitude, double longitude) {
  final lat = (latitude * 20).round() / 20;
  final lng = (longitude * 20).round() / 20;
  return '${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}';
}

/// Reads journal rows, including coordinates stored in ambient metadata.
abstract final class TimelineHeatmapStore {
  static Future<List<TimelineMapEntry>> load(DatabaseExecutor db) async {
    final hidden = await PrivateVaultGate.andSql(db, '');
    try {
      final rows = await db.rawQuery('''
        SELECT id, created_at, transcript, ambient_metadata
        FROM journal_entries
        WHERE deleted_at IS NULL$hidden
        ORDER BY created_at DESC, id DESC
      ''');
      return rows.map(_entry).toList(growable: false);
    } on Object {
      final rows = await db.rawQuery('''
        SELECT id, created_at, transcript
        FROM journal_entries
        WHERE deleted_at IS NULL$hidden
        ORDER BY created_at DESC, id DESC
      ''');
      return rows.map(_entry).toList(growable: false);
    }
  }

  static TimelineMapEntry _entry(Map<String, Object?> row) {
    final created = row['created_at'];
    final millis = created is int ? created : 0;
    final metadata = AmbientMetadata.decode(
      row[Migration021AmbientMetadata.column] as String?,
    );
    final transcript = row['transcript'] as String? ?? '';
    return TimelineMapEntry(
      id: row['id'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(millis),
      transcript: transcript,
      sentiment: entrySentiment(transcript),
      latitude: metadata?.latitude,
      longitude: metadata?.longitude,
    );
  }
}

double _mean(Iterable<double> values) {
  final list = values.toList(growable: false);
  if (list.isEmpty) return 0;
  var total = 0.0;
  for (final value in list) {
    total += value;
  }
  return total / list.length;
}

const _positive = {
  'grateful',
  'calm',
  'hopeful',
  'glad',
  'better',
  'peace',
  'happy',
  'good',
};

const _negative = {
  'anxious',
  'stressed',
  'angry',
  'sad',
  'tired',
  'worse',
  'afraid',
};
