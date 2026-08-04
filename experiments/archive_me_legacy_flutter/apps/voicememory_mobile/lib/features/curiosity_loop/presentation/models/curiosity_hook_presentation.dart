import '../../domain/models/cognitive_biomarkers.dart';
import '../../domain/models/curiosity_hook.dart';
import '../../domain/services/cognitive_anomaly_detector.dart';
import '../../domain/services/curiosity_prompt_generator.dart';

/// UI-facing curiosity hook state for presentation surfaces.
class CuriosityHookPresentation {
  const CuriosityHookPresentation({
    required this.id,
    required this.prompt,
    required this.isMemoryRecallCheck,
    this.sourceEntryId,
    required this.isLowCognitiveLoad,
  });

  final String id;
  final String prompt;
  final bool isMemoryRecallCheck;
  final String? sourceEntryId;
  final bool isLowCognitiveLoad;

  /// Maps a domain-level [CuriosityHook] to the presentation surface model.
  ///
  /// Captures personalized allostatic overload by passing [currentMetrics] and
  /// [baselineMetrics] to the [CognitiveAnomalyDetector]. Seamlessly falls back
  /// to legacy heuristic rules if historical metrics are absent.
  factory CuriosityHookPresentation.fromDomain(
    CuriosityHook hook, {
    CognitiveBiomarkers? currentMetrics,
    CognitiveBiomarkers? baselineMetrics,
    double? sourceLexicalDiversity,
    CognitiveAnomalyDetector detector = const CognitiveAnomalyDetector(),
  }) {
    final bool lowLoadActive;

    if (currentMetrics != null && baselineMetrics != null) {
      lowLoadActive = detector.determineOverloadState(
        current: currentMetrics,
        baseline: baselineMetrics,
      );
    } else {
      final hasLowLoadTail = hook.dynamicPrompt.contains(
        DefaultCuriosityPromptGenerator.lowCognitiveLoadTail,
      );
      final isRestrictedSource =
          hook.isMemoryRecallCheck &&
          sourceLexicalDiversity != null &&
          sourceLexicalDiversity <
              DefaultCuriosityPromptGenerator().lowLexicalDiversityThreshold;

      lowLoadActive = hasLowLoadTail || isRestrictedSource;
    }

    return CuriosityHookPresentation(
      id: hook.id,
      prompt: hook.dynamicPrompt,
      isMemoryRecallCheck: hook.isMemoryRecallCheck,
      sourceEntryId: hook.sourceEntryId,
      isLowCognitiveLoad: lowLoadActive,
    );
  }
}
