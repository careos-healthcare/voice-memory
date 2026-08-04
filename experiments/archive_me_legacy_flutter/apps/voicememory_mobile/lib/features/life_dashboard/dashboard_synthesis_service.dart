import '../../api/journal_sync_api_client.dart';
import '../../services/ai/hybrid_ai_router.dart';
import '../ai_engines/models/ai_explainability.dart';
import '../ai_engines/models/hypothesis_evolution.dart';
import 'life_dashboard_models.dart';

class DashboardSynthesisService {
  const DashboardSynthesisService({required this.router, required this.api});

  final HybridAiRouter router;
  final JournalSyncApiClient api;

  Future<DashboardSynthesizedPayload?> synthesize({
    required TimeHorizon horizon,
    required String userId,
    required Map<String, dynamic> localMetrics,
    required List<Map<String, dynamic>> evidence,
    required bool isOnline,
  }) async {
    if (horizon == TimeHorizon.today) return null;
    final result = await router.execute(
      HybridAiRequest(
        operation: horizon == TimeHorizon.thisMonth
            ? HybridAiOperation.monthlyLifeStorySynthesis
            : HybridAiOperation.crossTemporalReasoning,
        query: 'Life Dashboard ${horizon.label}',
        userInitiated: true,
        isOnline: isOnline,
        estimatedOutputTokens: 900,
      ),
      cloudWithContext: (context) async {
        final payload = await api.postDashboardSynthesis(
          userId: userId,
          horizon: switch (horizon) {
            TimeHorizon.today => 'today',
            TimeHorizon.thisMonth => 'this_month',
            TimeHorizon.thisYear => 'this_year',
          },
          localMetrics: localMetrics,
          evidence: evidence,
          activeHypotheses: context.activeHypothesesJson,
          truthAnchors: context.truthAnchors,
        );
        return HybridCloudResult(payload: payload);
      },
    );
    final payload = result.cloudPayload;
    if (payload is! Map) return null;
    final synthesized = DashboardSynthesizedPayload.fromApiJson(
      Map<String, dynamic>.from(payload),
    );
    await router.persistHypotheses(_hypotheses(synthesized));
    return synthesized;
  }

  static List<HypothesisEvolution> _hypotheses(
    DashboardSynthesizedPayload synthesized,
  ) {
    final result = <HypothesisEvolution>[];
    void add(String statement, AiExplainability? explainability) {
      final theoryId = explainability?.theoryId;
      if (theoryId == null || explainability!.evolutionHistory.isEmpty) return;
      result.add(
        HypothesisEvolution(
          theoryId: theoryId,
          statement: statement,
          evolutionHistory: explainability.evolutionHistory,
        ),
      );
    }

    final identity = synthesized.identity;
    if (identity != null) {
      add(identity.coreBeliefs.join('; '), identity.explainability);
    }
    for (final goal in synthesized.goals) {
      add(goal.label, goal.explainability);
    }
    for (final prediction in synthesized.predictions) {
      add(prediction.statement, prediction.explainability);
    }
    return result;
  }
}
