import 'dart:collection';

enum LifeStoryPointKind {
  node,
  relationship,
  semanticCluster,
  identityShift,
  simulationMilestone,
}

final class LifeStoryPoint {
  LifeStoryPoint({
    required this.id,
    required this.kind,
    required DateTime timestamp,
    required num significance,
    required num sentiment,
    Iterable<String> nodeIds = const [],
    Iterable<String> clusterIds = const [],
    this.projected = false,
  }) : timestamp = timestamp.toUtc(),
       significance = significance.toDouble().clamp(0, 1),
       sentiment = sentiment.toDouble().clamp(-1, 1),
       nodeIds = List.unmodifiable(nodeIds.toSet()),
       clusterIds = List.unmodifiable(clusterIds.toSet());

  final String id;
  final LifeStoryPointKind kind;
  final DateTime timestamp;
  final double significance;
  final double sentiment;
  final List<String> nodeIds;
  final List<String> clusterIds;
  final bool projected;

  Map<String, Object> toJson() => {
    'id': id,
    'kind': kind.name,
    'timestamp': timestamp.toIso8601String(),
    'significance': significance,
    'sentiment': sentiment,
    'nodeIds': nodeIds,
    'clusterIds': clusterIds,
    'projected': projected,
  };

  factory LifeStoryPoint.fromJson(Map<String, dynamic> json) => LifeStoryPoint(
    id: json['id'] as String,
    kind: LifeStoryPointKind.values.byName(json['kind'] as String),
    timestamp: DateTime.parse(json['timestamp'] as String),
    significance: json['significance'] as num,
    sentiment: json['sentiment'] as num,
    nodeIds: (json['nodeIds'] as List? ?? const []).whereType<String>(),
    clusterIds: (json['clusterIds'] as List? ?? const []).whereType<String>(),
    projected: json['projected'] == true,
  );
}

final class LifeStoryChapter {
  LifeStoryChapter({
    required this.id,
    required this.title,
    required this.ordinal,
    required DateTime start,
    required DateTime end,
    required Iterable<LifeStoryPoint> points,
  }) : start = start.toUtc(),
       end = end.toUtc(),
       points = UnmodifiableListView(points);

  final String id;
  final String title;
  final int ordinal;
  final DateTime start;
  final DateTime end;
  final List<LifeStoryPoint> points;

  double get averageSentiment => points.isEmpty
      ? 0
      : points.fold<double>(0, (sum, point) => sum + point.sentiment) /
            points.length;

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'ordinal': ordinal,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'points': points.map((point) => point.toJson()).toList(),
  };
}

final class LifeStoryTimeline {
  LifeStoryTimeline({
    required this.id,
    required Iterable<LifeStoryPoint> points,
    required Iterable<LifeStoryChapter> chapters,
    required DateTime generatedAt,
  }) : points = UnmodifiableListView(points),
       chapters = UnmodifiableListView(chapters),
       generatedAt = generatedAt.toUtc();

  final String id;
  final List<LifeStoryPoint> points;
  final List<LifeStoryChapter> chapters;
  final DateTime generatedAt;
}

final class ReplayCameraCue {
  ReplayCameraCue({
    required this.offset,
    Iterable<String> nodeIds = const [],
    Iterable<String> clusterIds = const [],
    this.emphasis = 1,
  }) : nodeIds = List.unmodifiable(nodeIds),
       clusterIds = List.unmodifiable(clusterIds);

  final Duration offset;
  final List<String> nodeIds;
  final List<String> clusterIds;
  final double emphasis;
}

final class LifeStoryScriptChapter {
  LifeStoryScriptChapter({
    required this.id,
    required this.title,
    required this.narration,
    required this.start,
    required this.duration,
    required Iterable<ReplayCameraCue> cues,
  }) : cues = UnmodifiableListView(cues);

  final String id;
  final String title;
  final String narration;
  final Duration start;
  final Duration duration;
  final List<ReplayCameraCue> cues;
}

final class LifeStoryReplayScript {
  LifeStoryReplayScript({
    required this.id,
    required this.title,
    required Iterable<LifeStoryScriptChapter> chapters,
  }) : chapters = UnmodifiableListView(chapters);

  final String id;
  final String title;
  final List<LifeStoryScriptChapter> chapters;

  Duration get duration => chapters.fold(
    Duration.zero,
    (maximum, chapter) => chapter.start + chapter.duration > maximum
        ? chapter.start + chapter.duration
        : maximum,
  );

  String get narration =>
      chapters.map((chapter) => chapter.narration).join('\n\n');
}
