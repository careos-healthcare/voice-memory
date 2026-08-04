import '../../api/journal_sync_api_client.dart';
import '../../features/archive_evidence/comparable_evidence_text.dart';
import '../../models/journal_entry.dart';
import '../../services/ai/hybrid_ai_router.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import '../ai_engines/models/hypothesis_evolution.dart';
import 'weekly_intelligence_models.dart';

class WeeklyIntelligenceSynthesisService {
  const WeeklyIntelligenceSynthesisService({
    required this.router,
    required this.api,
  });

  final HybridAiRouter router;
  final JournalSyncApiClient api;

  Future<WeeklyIntelligenceSnapshot?> synthesize({
    required String userId,
    required WeeklyIntelligenceSnapshot local,
    required List<JournalEntry> entries,
    required bool isOnline,
  }) async {
    final evidence = [
      for (final entry in entries)
        if (ComparableEvidenceText.userText(entry).trim().isNotEmpty &&
            entry.createdAt.toUtc().isBefore(local.weekEnd) &&
            !entry.createdAt.toUtc().isBefore(
              local.weekStart.subtract(
                Duration(days: 7 * local.baselineWeekCount),
              ),
            ))
          {
            'sourceEntryId': entry.id,
            'week': entry.createdAt.toUtc().isBefore(local.weekStart)
                ? 'baseline'
                : 'current',
            'occurredAt': entry.createdAt.toUtc().toIso8601String(),
            'canonicalTranscript': ComparableEvidenceText.userText(entry),
          },
    ];
    if (!evidence.any((item) => item['week'] == 'baseline') ||
        !evidence.any((item) => item['week'] == 'current')) {
      return null;
    }
    final result = await router.execute(
      HybridAiRequest(
        operation: HybridAiOperation.scheduledBackgroundBatch,
        query: 'Sunday behavioral intelligence ${local.weekKey}',
        userInitiated: false,
        scheduled: true,
        isOnline: isOnline,
        estimatedOutputTokens: 1200,
      ),
      cloudWithContext: (context) async {
        final payload = await api.postWeeklyIntelligenceSynthesis(
          userId: userId,
          weekStart: local.weekStart.toIso8601String(),
          weekEnd: local.weekEnd.toIso8601String(),
          baselineWeekCount: local.baselineWeekCount,
          localDeltas: [
            for (final delta in local.deltas)
              {
                'id': delta.id,
                'dimension': _wireDimension(delta.dimension),
                'magnitude': delta.magnitude,
                'nodeIds': delta.nodeIds.toList(),
                'statement': delta.statement,
              },
          ],
          evidence: evidence,
          activeHypotheses: context.activeHypothesesJson,
          truthAnchors: context.truthAnchors,
        );
        return HybridCloudResult(payload: payload);
      },
    );
    if (result.cloudPayload case final Map payload) {
      final synthesized = _parse(
        Map<String, dynamic>.from(payload),
        local: local,
      );
      await router.persistHypotheses([
        for (final delta in synthesized.deltas)
          if (delta.explainability.theoryId != null &&
              delta.explainability.evolutionHistory.isNotEmpty)
            HypothesisEvolution(
              theoryId: delta.explainability.theoryId!,
              statement: delta.statement,
              evolutionHistory: delta.explainability.evolutionHistory,
            ),
      ]);
      return synthesized;
    }
    return null;
  }

  static WeeklyIntelligenceSnapshot _parse(
    Map<String, dynamic> json, {
    required WeeklyIntelligenceSnapshot local,
  }) {
    final raw = json['deltas'];
    if (raw is! List) {
      throw const FormatException('Weekly deltas must be a list.');
    }
    final deltas = <BehavioralDelta>[];
    for (final item in raw) {
      if (item is! Map) {
        throw const FormatException('Invalid weekly delta.');
      }
      final map = Map<String, dynamic>.from(item);
      final conclusion = ExplainableConclusion.fromJson(map['conclusion']);
      if (conclusion == null) {
        throw const FormatException('Weekly delta requires V4 explainability.');
      }
      final explainability = aiExplainabilityFromV4(conclusion);
      if (explainability.evidence.length < 2) {
        throw const FormatException('Weekly delta requires paired evidence.');
      }
      final nodeIds = (map['nodeIds'] as List? ?? const [])
          .map((id) => '$id')
          .toSet();
      final magnitude = (map['magnitude'] as num?)?.toDouble() ?? 0;
      final common = (
        id: conclusion.id,
        title: conclusion.statement,
        statement: conclusion.statement,
        magnitude: magnitude,
        direction: _direction(magnitude),
        nodeIds: nodeIds,
        explainability: explainability,
      );
      deltas.add(switch (map['dimension']) {
        'action_intent_ratio' => ActionIntentRatio(
          id: common.id,
          title: common.title,
          statement: common.statement,
          magnitude: common.magnitude,
          direction: common.direction,
          nodeIds: common.nodeIds,
          explainability: common.explainability,
          baselineIntentCount: 0,
          currentActionCount: 0,
          executionRatio: magnitude,
        ),
        'emotional_velocity' => EmotionalVelocity(
          id: common.id,
          title: common.title,
          statement: common.statement,
          magnitude: common.magnitude,
          direction: common.direction,
          nodeIds: common.nodeIds,
          explainability: common.explainability,
          baselineTone: 0,
          currentTone: magnitude,
        ),
        'habit_drift' => HabitDrift(
          id: common.id,
          title: common.title,
          statement: common.statement,
          magnitude: common.magnitude,
          direction: common.direction,
          nodeIds: common.nodeIds,
          explainability: common.explainability,
          habitLabel: common.title,
          baselineWeeklyMentions: 0,
          currentMentions: 0,
          frictionPoints: const [],
        ),
        'relationship_dynamics' => RelationshipDynamicsDelta(
          id: common.id,
          title: common.title,
          statement: common.statement,
          magnitude: common.magnitude,
          direction: common.direction,
          nodeIds: common.nodeIds,
          explainability: common.explainability,
          personLabel: common.title,
          frequencyDelta: 0,
          valenceDelta: magnitude,
        ),
        'identity_shift' => IdentityShiftDelta(
          id: common.id,
          title: common.title,
          statement: common.statement,
          magnitude: common.magnitude,
          direction: DeltaDirection.shifted,
          nodeIds: common.nodeIds,
          explainability: common.explainability,
          previousBelief: '',
          currentBelief: common.statement,
        ),
        _ => throw const FormatException('Unknown weekly delta dimension.'),
      });
    }
    return WeeklyIntelligenceSnapshot(
      weekStart: local.weekStart,
      weekEnd: local.weekEnd,
      baselineWeekCount: local.baselineWeekCount,
      deltas: deltas,
      localSemanticMatches: local.localSemanticMatches,
      generatedAt: DateTime.now().toUtc(),
    );
  }

  static String _wireDimension(BehavioralDeltaDimension value) =>
      switch (value) {
        BehavioralDeltaDimension.actionIntentRatio => 'action_intent_ratio',
        BehavioralDeltaDimension.emotionalVelocity => 'emotional_velocity',
        BehavioralDeltaDimension.habitDrift => 'habit_drift',
        BehavioralDeltaDimension.relationshipDynamics =>
          'relationship_dynamics',
        BehavioralDeltaDimension.identityShift => 'identity_shift',
      };

  static DeltaDirection _direction(double value) {
    if (value > .05) return DeltaDirection.increased;
    if (value < -.05) return DeltaDirection.decreased;
    return DeltaDirection.stable;
  }
}
