import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/curiosity_hook.dart';
import 'package:voicememory_mobile/features/curiosity_loop/presentation/models/curiosity_hook_presentation.dart';

void main() {
  group('CuriosityHookPresentation.fromDomain Anomaly Mapping Tests', () {
    final baseDomainHook = CuriosityHook(
      id: 'hook_123',
      entryId: 'entry_789',
      createdAt: DateTime.utc(2026, 6, 12, 12),
      primaryAnchor: 'morning reflection',
      hookType: CuriosityHookType.anchorFollowUp,
      dynamicPrompt: 'Explore your morning reflection.',
      isMemoryRecallCheck: true,
      sourceEntryId: 'entry_789',
    );

    test(
      'should activate low load styling when personalized metrics flag an anomaly drop',
      () {
        const baseline = CognitiveBiomarkers(
          lexicalDiversity: 0.65,
          cohesionDrift: 0.30,
          emotionalVolatility: 0.20,
        );

        // Severe structural collapse (+0.20 drift) flags an anomaly
        const current = CognitiveBiomarkers(
          lexicalDiversity: 0.62,
          cohesionDrift: 0.50,
          emotionalVolatility: 0.35,
        );

        final presentation = CuriosityHookPresentation.fromDomain(
          baseDomainHook,
          currentMetrics: current,
          baselineMetrics: baseline,
        );

        expect(presentation.isLowCognitiveLoad, isTrue);
      },
    );

    test(
      'should keep standard layout when metrics reflect minor normal baseline variations',
      () {
        const baseline = CognitiveBiomarkers(
          lexicalDiversity: 0.50,
          cohesionDrift: 0.40,
          emotionalVolatility: 0.30,
        );

        const current = CognitiveBiomarkers(
          lexicalDiversity: 0.48, // -0.02 variation (under the 0.10 threshold)
          cohesionDrift: 0.45, // +0.05 variation (under the 0.15 threshold)
          emotionalVolatility: 0.32,
        );

        final presentation = CuriosityHookPresentation.fromDomain(
          baseDomainHook,
          currentMetrics: current,
          baselineMetrics: baseline,
        );

        expect(presentation.isLowCognitiveLoad, isFalse);
      },
    );

    test(
      'should fallback to text string matching rules if metrics payloads are omitted',
      () {
        final lowLoadTextHook = CuriosityHook(
          id: 'hook_abc',
          entryId: 'entry_abc',
          createdAt: DateTime.utc(2026, 6, 12, 12),
          primaryAnchor: 'feelings',
          hookType: CuriosityHookType.blocker,
          dynamicPrompt: 'Tell us how you feel. Short thoughts are perfect.',
          isMemoryRecallCheck: false,
        );

        final presentation = CuriosityHookPresentation.fromDomain(
          lowLoadTextHook,
          currentMetrics: null,
          baselineMetrics: null,
        );

        expect(presentation.isLowCognitiveLoad, isTrue);
      },
    );
  });
}
