import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../api/api_transport.dart';
import '../../services/capture_attest_service.dart';
import 'morning_briefing_models.dart';

class MorningBriefingSynthesisResult {
  const MorningBriefingSynthesisResult({
    required this.briefing,
    this.audioBytes,
  });

  final MorningBriefing briefing;
  final Uint8List? audioBytes;
}

abstract interface class MorningBriefingSynthesizer {
  Future<MorningBriefingSynthesisResult> synthesize(
    MorningBriefingPayload payload,
  );
}

class CloudMorningBriefingSynthesizer implements MorningBriefingSynthesizer {
  CloudMorningBriefingSynthesizer({
    required this.transport,
    required this.attest,
    required this.fallback,
    Random? random,
  }) : _random = random ?? Random.secure();

  final ApiTransport transport;
  final CaptureAttestService attest;
  final MorningBriefingSynthesizer fallback;
  final Random _random;

  Map<String, Object?> buildAnonymizedPayload(MorningBriefingPayload payload) =>
      _anonymize(payload).payload;

  @override
  Future<MorningBriefingSynthesisResult> synthesize(
    MorningBriefingPayload payload,
  ) async {
    try {
      final prepared = _anonymize(payload);
      final token = await attest.ensureCaptureToken();
      final response = await transport.postJson(
        '/api/morning-briefing',
        headers: {
          ...transport.jsonHeaders,
          ApiTransport.captureTokenHeader: token,
          'x-vm-client': 'voicememory-mobile',
        },
        body: prepared.payload,
      );
      return _parse(
        transport.decodeJson(response),
        source: payload,
        localIdByOpaque: prepared.localIdByOpaque,
      );
    } on Object {
      return fallback.synthesize(payload);
    }
  }

  _PreparedMorningPayload _anonymize(MorningBriefingPayload source) {
    String opaque(String prefix) =>
        '$prefix-${List.generate(12, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final nodeIds = {
      for (final habit in source.incompleteHabits) habit.targetNodeId,
      for (final cluster in source.clusterSignals) ...cluster.nodeIds,
    };
    final nodeOpaque = {for (final id in nodeIds) id: opaque('n')};
    final clusterOpaque = {
      for (final cluster in source.clusterSignals)
        cluster.clusterId: opaque('c'),
    };
    final localIdByOpaque = {
      for (final entry in nodeOpaque.entries) entry.value: entry.key,
      for (final entry in clusterOpaque.entries) entry.value: entry.key,
    };
    return _PreparedMorningPayload(
      localIdByOpaque: localIdByOpaque,
      payload: {
        'restMetrics': {
          'windowDays': 1,
          'sleepDurationMinutes': source.sleepHours == null
              ? null
              : (source.sleepHours! * 60).round(),
          'sleepConsistencyScore': null,
          'recoveryScore': source.sleepHours == null
              ? null
              : source.sleepQualityScore / 100,
          'restingHeartRateBpm':
              source.restingHeartRate != null &&
                  source.restingHeartRate! >= 30 &&
                  source.restingHeartRate! <= 220
              ? source.restingHeartRate
              : null,
        },
        'incompleteMicroHabits': [
          for (final habit in source.incompleteHabits)
            {
              'habitId': opaque('h'),
              'targetNodeId': nodeOpaque[habit.targetNodeId],
              'completionRate': habit.currentRun == 0
                  ? 0.0
                  : habit.currentRun / (habit.currentRun + 1),
              'daysIncomplete': 1,
            },
        ],
        'semanticClusterVelocityDeltas': [
          for (final cluster in source.clusterSignals)
            {
              'clusterId': clusterOpaque[cluster.clusterId],
              'velocityDelta': cluster.velocityDelta.clamp(-1.0, 1.0),
              'activityScore': cluster.velocity.clamp(0.0, 1.0),
            },
        ],
        'journalTopicSignals': [
          for (var index = 0; index < source.topicSignals.length; index++)
            {
              'topicId': opaque('t'),
              'relatedNodeIds': <String>[],
              'salienceScore': (1 - index / source.topicSignals.length).clamp(
                0.0,
                1.0,
              ),
              'velocityDelta': 0.0,
            },
        ],
      },
    );
  }

  MorningBriefingSynthesisResult _parse(
    Map<String, dynamic> json, {
    required MorningBriefingPayload source,
    required Map<String, String> localIdByOpaque,
  }) {
    final briefingJson = json['briefing'] is Map
        ? Map<String, dynamic>.from(json['briefing'] as Map)
        : json;
    final sections = briefingJson['sections'];
    if (sections is! List || sections.length != 3) {
      throw const FormatException('Invalid morning briefing sections.');
    }
    final parsedSections = sections.map((raw) {
      if (raw is! Map) throw const FormatException('Invalid section.');
      final value = Map<String, dynamic>.from(raw);
      return MorningBriefingSection(
        kind: _sectionKind('${value['title']}'),
        title: '${value['title']}',
        narrative: '${value['ttsText']}',
      );
    }).toList();
    final highlightedNodes = sections
        .whereType<Map>()
        .expand(
          (section) => (section['highlightedNodeIds'] as List? ?? const []),
        )
        .map((id) => localIdByOpaque[id?.toString()])
        .whereType<String>();
    final highlightedClusters = sections
        .whereType<Map>()
        .expand(
          (section) => (section['highlightedClusterIds'] as List? ?? const []),
        )
        .map((id) => localIdByOpaque[id?.toString()])
        .whereType<String>();
    final briefing = MorningBriefing(
      id: 'morning-${_date(source.localDay)}',
      localDay: source.localDay,
      generatedAt: DateTime.now(),
      sections: parsedSections,
      sleepQualityScore: source.sleepQualityScore,
      activeHabitCount: source.incompleteHabits.length,
      bestHabitRun: source.incompleteHabits.fold(
        0,
        (best, habit) => max(best, habit.currentRun),
      ),
      highlightedNodeId: highlightedNodes.firstOrNull,
      highlightedClusterId: highlightedClusters.firstOrNull,
      encryptedAudioAvailable: json['audioBase64'] is String,
    );
    final audio = json['audioBase64'];
    return MorningBriefingSynthesisResult(
      briefing: briefing,
      audioBytes: audio is String && audio.isNotEmpty
          ? Uint8List.fromList(base64Decode(audio))
          : null,
    );
  }
}

class LocalMorningBriefingAiService implements MorningBriefingSynthesizer {
  const LocalMorningBriefingAiService();

  @override
  Future<MorningBriefingSynthesisResult> synthesize(
    MorningBriefingPayload payload,
  ) async {
    final leadingCluster = payload.clusterSignals.firstOrNull;
    final leadingHabit = payload.incompleteHabits.firstOrNull;
    final rest = payload.sleepHours == null
        ? 'No sleep reading is available this morning, so leave that gap open '
              'instead of guessing. Begin gently and notice your energy before '
              'committing to a demanding pace. A glass of water, daylight, and '
              'one quiet minute can provide better evidence than an absent '
              'score. Treat how you feel as context, not a verdict on the day.'
        : 'You recorded ${payload.sleepHours!.toStringAsFixed(1)} hours of sleep. '
              'Your recovery score is ${payload.sleepQualityScore} out of 100. '
              'Use those numbers as a limited snapshot rather than a diagnosis. '
              'Notice whether your attention feels aligned with the reading, '
              'then choose a pace that fits the energy actually available. '
              'There is no need to compensate for imperfect rest all at once.';
    final momentum = leadingCluster == null
        ? 'Your graph is quiet this morning, and quiet is useful information. '
              'There is no emerging pattern that needs to be forced into a '
              'story. One clear entry today is enough to create momentum. '
              'Capture what holds your attention, keep the language concrete, '
              'and allow the larger shape to become visible over time.'
        : '${leadingCluster.label} has the strongest recent movement. '
              'Its pace changed by ${(leadingCluster.velocityDelta * 100).round()} percent. '
              'That direction does not explain why it changed, but it marks a '
              'useful place to look. Give this cluster a deliberate moment '
              'without letting it consume the whole day. Notice what is moving, '
              'what is stalled, and which next observation would reduce uncertainty.';
    final focus = leadingHabit == null
        ? 'For today’s single focus, choose one small action that makes tonight '
              'easier, and let the rest stay optional. Make the first step '
              'specific enough to begin in under five minutes. Completion is '
              'less important than creating a clean starting cue. After that '
              'step, pause and decide whether continuing still serves the day.'
        : 'Make ${leadingHabit.title.toLowerCase()} your single focus. '
              'It reconnects you with the node that matters most today. Keep '
              'the action intentionally small; you are not trying to repair '
              'every missed day or protect a perfect streak. Create one clear '
              'opportunity to begin, complete the smallest useful version, and '
              'then reassess. Adapting the step to your actual capacity still '
              'counts as informed follow-through.';
    final briefing = MorningBriefing(
      id: 'morning-${_date(payload.localDay)}',
      localDay: payload.localDay,
      generatedAt: DateTime.now(),
      sections: [
        MorningBriefingSection(
          kind: MorningBriefingSectionKind.restAndRecovery,
          title: 'Rest & Recovery',
          narrative: rest,
        ),
        MorningBriefingSection(
          kind: MorningBriefingSectionKind.mindMapMomentum,
          title: 'Mind Map Momentum',
          narrative: momentum,
        ),
        MorningBriefingSection(
          kind: MorningBriefingSectionKind.todaysSingleFocus,
          title: "Today's Single Focus",
          narrative: focus,
        ),
      ],
      sleepQualityScore: payload.sleepQualityScore,
      activeHabitCount: payload.incompleteHabits.length,
      bestHabitRun: payload.incompleteHabits.fold(
        0,
        (best, habit) => max(best, habit.currentRun),
      ),
      highlightedNodeId: leadingHabit?.targetNodeId,
      highlightedClusterId: leadingCluster?.clusterId,
      generatedOffline: true,
    );
    return MorningBriefingSynthesisResult(briefing: briefing);
  }
}

MorningBriefingSectionKind _sectionKind(String value) {
  return switch (value) {
    'Rest & Recovery' => MorningBriefingSectionKind.restAndRecovery,
    'Mind Map Momentum' => MorningBriefingSectionKind.mindMapMomentum,
    "Today's Single Focus" => MorningBriefingSectionKind.todaysSingleFocus,
    _ => throw const FormatException('Invalid morning briefing section kind.'),
  };
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

class _PreparedMorningPayload {
  const _PreparedMorningPayload({
    required this.payload,
    required this.localIdByOpaque,
  });

  final Map<String, Object?> payload;
  final Map<String, String> localIdByOpaque;
}
