import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../api/api_transport.dart';
import '../../services/capture_attest_service.dart';
import 'life_story_models.dart';

final class LifeStorySynthesisResult {
  const LifeStorySynthesisResult({
    required this.script,
    this.audioChunks = const {},
  });

  final LifeStoryReplayScript script;
  final Map<String, Uint8List> audioChunks;
}

abstract interface class LifeStoryReplaySynthesizer {
  Future<LifeStorySynthesisResult> synthesize(LifeStoryTimeline timeline);
}

final class CloudLifeStoryReplaySynthesizer
    implements LifeStoryReplaySynthesizer {
  CloudLifeStoryReplaySynthesizer({
    required this.transport,
    required this.attest,
    required this.fallback,
    Random? random,
  }) : _random = random ?? Random.secure();

  final ApiTransport transport;
  final CaptureAttestService attest;
  final LifeStoryReplaySynthesizer fallback;
  final Random _random;

  @override
  Future<LifeStorySynthesisResult> synthesize(
    LifeStoryTimeline timeline,
  ) async {
    try {
      final prepared = _anonymize(timeline);
      final token = await attest.ensureCaptureToken();
      final response = await transport.postJson(
        '/api/life-story-replay',
        headers: {
          ...transport.jsonHeaders,
          ApiTransport.captureTokenHeader: token,
          'x-vm-client': 'voicememory-mobile',
        },
        body: prepared.payload,
      );
      return _parse(
        transport.decodeJson(response),
        timeline: timeline,
        localIdByOpaque: prepared.localIdByOpaque,
      );
    } on Object {
      return fallback.synthesize(timeline);
    }
  }

  _PreparedReplayPayload _anonymize(LifeStoryTimeline timeline) {
    String opaque(String prefix) =>
        '$prefix-${List.generate(12, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final pointIds = {
      for (final point in timeline.points) point.id: opaque('m'),
    };
    final nodeIds = {
      for (final point in timeline.points)
        for (final nodeId in point.nodeIds) nodeId: opaque('n'),
    };
    final clusterIds = {
      for (final point in timeline.points)
        for (final clusterId in point.clusterIds) clusterId: opaque('c'),
    };
    final chapterIds = {
      for (final chapter in timeline.chapters) chapter.id: opaque('ch'),
    };
    final localIdByOpaque = <String, String>{
      for (final entry in nodeIds.entries) entry.value: entry.key,
      for (final entry in clusterIds.entries) entry.value: entry.key,
      for (final entry in chapterIds.entries) entry.value: entry.key,
    };
    final points = timeline.points.take(160).toList();
    final included = points.map((point) => point.id).toSet();
    return _PreparedReplayPayload(
      localIdByOpaque: localIdByOpaque,
      payload: {
        'version': 'life-story-replay-v1',
        'milestones': [
          for (final point in points)
            {
              'id': pointIds[point.id],
              'timestampMs': point.timestamp.millisecondsSinceEpoch,
              'kind': point.kind.name,
              'significance': point.significance,
              'sentiment': point.sentiment,
              'nodeIds': point.nodeIds
                  .map((id) => nodeIds[id]!)
                  .take(24)
                  .toList(),
              'clusterIds': point.clusterIds
                  .map((id) => clusterIds[id]!)
                  .take(24)
                  .toList(),
              'projected': point.projected,
            },
        ],
        'chapters': [
          for (final chapter in timeline.chapters.take(16))
            {
              'id': chapterIds[chapter.id],
              'ordinal': chapter.ordinal,
              'startMs': chapter.start.millisecondsSinceEpoch,
              'endMs': chapter.end.millisecondsSinceEpoch,
              'milestoneIds': chapter.points
                  .where((point) => included.contains(point.id))
                  .map((point) => pointIds[point.id]!)
                  .take(24)
                  .toList(),
            },
        ],
      },
    );
  }

  LifeStorySynthesisResult _parse(
    Map<String, dynamic> json, {
    required LifeStoryTimeline timeline,
    required Map<String, String> localIdByOpaque,
  }) {
    final replay = Map<String, dynamic>.from(json['replay'] as Map);
    final rawChapters = replay['chapters'] as List;
    var start = Duration.zero;
    final chapters = <LifeStoryScriptChapter>[];
    final opaqueChapterToLocal = <String, String>{};
    for (final raw in rawChapters.whereType<Map>()) {
      final value = Map<String, dynamic>.from(raw);
      final opaqueId = value['id'] as String;
      final localId = localIdByOpaque[opaqueId];
      if (localId == null) throw const FormatException('Unknown chapter ID.');
      opaqueChapterToLocal[opaqueId] = localId;
      final duration = Duration(milliseconds: value['durationMs'] as int);
      final cues = <ReplayCameraCue>[];
      for (final rawCue in (value['cues'] as List).whereType<Map>()) {
        final cue = Map<String, dynamic>.from(rawCue);
        cues.add(
          ReplayCameraCue(
            offset: Duration(milliseconds: cue['offsetMs'] as int),
            nodeIds: (cue['nodeIds'] as List)
                .map((id) => localIdByOpaque[id])
                .whereType<String>(),
            clusterIds: (cue['clusterIds'] as List)
                .map((id) => localIdByOpaque[id])
                .whereType<String>(),
            emphasis: (cue['emphasis'] as num).toDouble(),
          ),
        );
      }
      chapters.add(
        LifeStoryScriptChapter(
          id: localId,
          title: value['title'] as String,
          narration: value['narration'] as String,
          start: start,
          duration: duration,
          cues: cues,
        ),
      );
      start += duration;
    }
    final audio = <String, Uint8List>{};
    for (final raw
        in (json['audioChunks'] as List? ?? const []).whereType<Map>()) {
      final opaqueId = raw['chapterId']?.toString();
      final localId = opaqueChapterToLocal[opaqueId];
      final encoded = raw['audioBase64'];
      if (localId != null && encoded is String && encoded.isNotEmpty) {
        audio[localId] = Uint8List.fromList(base64Decode(encoded));
      }
    }
    return LifeStorySynthesisResult(
      script: LifeStoryReplayScript(
        id: timeline.id,
        title: replay['title'] as String,
        chapters: chapters,
      ),
      audioChunks: Map.unmodifiable(audio),
    );
  }
}

final class LocalLifeStoryReplaySynthesizer
    implements LifeStoryReplaySynthesizer {
  const LocalLifeStoryReplaySynthesizer();

  @override
  Future<LifeStorySynthesisResult> synthesize(
    LifeStoryTimeline timeline,
  ) async {
    var start = Duration.zero;
    final chapters = <LifeStoryScriptChapter>[];
    for (final chapter in timeline.chapters) {
      final duration = Duration(seconds: max(30, chapter.points.length * 9));
      final projected = chapter.points.any((point) => point.projected);
      chapters.add(
        LifeStoryScriptChapter(
          id: chapter.id,
          title: chapter.title,
          narration:
              '${chapter.title} gathers ${chapter.points.length} signals from '
              'this period into one chapter. The pattern reflects changing '
              'connections, emotional movement, and continuity without '
              'claiming a single cause. ${projected ? 'Its final moments are possible horizons, not settled history.' : 'Together, these moments show how attention and meaning gradually evolved.'}',
          start: start,
          duration: duration,
          cues: [
            for (var index = 0; index < min(chapter.points.length, 8); index++)
              ReplayCameraCue(
                offset: Duration(
                  milliseconds:
                      duration.inMilliseconds * index ~/ chapter.points.length,
                ),
                nodeIds: chapter.points[index].nodeIds.take(8),
                clusterIds: chapter.points[index].clusterIds.take(4),
                emphasis: chapter.points[index].significance,
              ),
          ],
        ),
      );
      start += duration;
    }
    return LifeStorySynthesisResult(
      script: LifeStoryReplayScript(
        id: timeline.id,
        title: 'A Life in Motion',
        chapters: chapters,
      ),
    );
  }
}

final class _PreparedReplayPayload {
  const _PreparedReplayPayload({
    required this.payload,
    required this.localIdByOpaque,
  });

  final Map<String, Object> payload;
  final Map<String, String> localIdByOpaque;
}
