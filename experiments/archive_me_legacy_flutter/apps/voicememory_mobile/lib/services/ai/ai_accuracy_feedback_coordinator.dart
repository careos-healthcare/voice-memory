import 'dart:async';

import '../../features/ai_engines/models/ai_accuracy_feedback.dart';
import '../../features/ai_engines/models/ai_explainability.dart';
import '../../features/ai_engines/feedback/graph_adaptation_engine.dart';
import '../app_services.dart';
import 'ai_accuracy_feedback_store.dart';

class AiAccuracyFeedbackCoordinator {
  const AiAccuracyFeedbackCoordinator();

  Future<AiAccuracyFeedback> submit({
    required String conclusionId,
    required String engine,
    required int confidencePercentage,
    required AiFeedbackState state,
    required List<VerifiableCitation> citations,
    String? correctionNote,
    Set<String> linkedNodeIds = const {},
    Set<String> linkedEdgeIds = const {},
    DateTime? now,
  }) async {
    final feedback = AiAccuracyFeedback(
      conclusionId: conclusionId,
      confidencePercentage: confidencePercentage,
      feedbackState: state,
      feedbackTimestamp: (now ?? DateTime.now()).toUtc(),
      correctionNote: correctionNote,
      engine: engine,
    );
    if (!AppServices.isInitialized) return feedback;
    final services = AppServices.instance;
    await AiAccuracyFeedbackStore(services.prefs).save(feedback);
    final learning =
        await GraphAdaptationEngine(
          graphStore: services.personalKnowledgeGraphStore,
          semanticStore: services.localSemanticStore,
        ).apply(
          feedback: feedback,
          citations: citations,
          linkedNodeIds: linkedNodeIds,
          linkedEdgeIds: linkedEdgeIds,
        );
    unawaited(
      services.journalSyncApi
          .postAiFeedback(
            conclusionId: feedback.conclusionId,
            engine: feedback.engine,
            confidencePercentage: feedback.confidencePercentage,
            feedbackState: feedback.feedbackState.name,
            feedbackTimestamp: feedback.feedbackTimestamp!,
            correctionNote: feedback.correctionNote,
            nodeIds: learning.affectedNodeIds,
            edgeIds: learning.affectedEdgeIds,
          )
          .catchError((Object _) {}),
    );
    return feedback;
  }
}
