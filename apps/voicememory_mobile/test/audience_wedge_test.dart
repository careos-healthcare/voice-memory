import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/acquisition/audience_wedge_model.dart';
import 'package:voicememory_mobile/features/acquisition/audience_wedge_store.dart';
import 'package:voicememory_mobile/features/interpretation/interpretation_quality_engine.dart';
import 'package:voicememory_mobile/features/quality/first_insight_specificity_store.dart';
import 'package:voicememory_mobile/features/retention/retention_diagnosis_v2_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/onboarding_intent_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/record/first_insight_sharpness_row.dart';
import 'package:voicememory_mobile/widgets/record/post_save_insight_choice_card.dart';
import 'package:voicememory_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:voicememory_mobile/features/first_session/first_session_pattern_category.dart';

JournalEntry _entry(String transcript) {
  return JournalEntry(
    id: 'e1',
    createdAt: DateTime(2026, 6, 1),
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

FirstSessionPattern _pattern() {
  return FirstSessionPattern(
    id: 'p1',
    createdAt: DateTime(2026, 6, 1),
    title: 'Taking responsibility before asking for help',
    whyNoticed: 'You mentioned pressure or responsibility.',
    watchForText: 'whether you take responsibility before asking for help',
    chips: const ['saying yes fast', 'pressure'],
    confidenceLabel: FirstSessionConfidenceLabel.early,
    sourceTextPreview: 'I said yes again.',
    matchReason: 'Your words pointed toward pressure in this moment.',
    confidenceScore: 0.55,
    categoryId: 'responsibility',
    category: FirstSessionPatternCategory.responsibility,
    alternativePatterns: const [
      FirstSessionPatternAlternative(
        title: 'Fear of disappointing someone',
        whyNoticed: 'You mentioned not wanting to disappoint someone.',
        watchForText: 'whether fear of disappointing someone shows up again',
        chips: ['disappoint'],
        confidenceScore: 0.4,
        categoryId: 'relationship',
      ),
    ],
  );
}

RetentionDiagnosisV2Input _diagInput({
  bool first = true,
  AudienceWedge? wedge,
  FirstInsightSpecificityRating? rating,
  String? lastReadId,
  bool entrySupports = false,
  bool second = false,
}) {
  return RetentionDiagnosisV2Input(
    firstMomentRecorded: first,
    secondMomentRecorded: second,
    thirdMomentRecorded: false,
    interpretationSignals: const [],
    reminderPrePromptShown: false,
    reminderPrePromptAccepted: false,
    reminderPrePromptDismissed: 0,
    reminderReturnCount: 0,
    onboardingIntent: null,
    journeyEvidenceCount: 1,
    reviewConfirmed: false,
    audienceWedge: wedge,
    firstInsightSpecificityRating: rating,
    lastReadTemplateId: lastReadId,
    entryTextSupportsWedge: entrySupports,
  );
}

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_wedge_journal_$stamp.json',
    prefsPath: '/tmp/vm_wedge_prefs_$stamp.json',
    skipRevenueCat: true,
  );
}

void main() {
  group('audience wedge selection', () {
    testWidgets('wedge question and options render', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingIntentScreen()),
      );
      expect(
        find.text(ConsumerUiCopy.acquisitionIntentQuestion),
        findsOneWidget,
      );
      expect(find.text('Saying yes when I have no capacity'), findsOneWidget);
      expect(find.text('Not sure yet'), findsOneWidget);
    });

    test('selection stored with timestamp', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      await AudienceWedgeStore.instance().save(AudienceWedge.proveEnough);
      expect(
        await AudienceWedgeStore.instance().load(),
        AudienceWedge.proveEnough,
      );
      expect(await AudienceWedgeStore.instance().selectedAt(), isNotNull);
    });

    test('first prompt changes by wedge', () async {
      expect(AudienceWedge.sayingYesCapacity.firstPrompt, contains('say yes'));
      expect(
        AudienceWedge.proveEnough.firstPrompt,
        contains('pressure to do more'),
      );
      expect(AudienceWedge.notSureYet.firstPrompt, contains('what felt heavy'));
    });

    test('legacy intent maps to wedge', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      final prefs = AppServices.instance.prefs;
      await prefs.writeMap('acquisitionIntent', {
        'intent': 'habitsRepeat',
        'selectedAt': DateTime.now().toUtc().toIso8601String(),
      });
      expect(
        await AudienceWedgeStore.instance().load(),
        AudienceWedge.repeatingHabit,
      );
    });
  });

  group('wedge interpretation ranking', () {
    const engine = InterpretationQualityEngine();

    test('boosts capacity read when wedge and text support it', () {
      final result = engine.build(
        latestEntry: _entry(
          'I agreed to help again because I did not want to disappoint them.',
        ),
        audienceWedge: AudienceWedge.sayingYesCapacity,
      );
      expect(
        result.reads.first.title.toLowerCase(),
        anyOf(contains('saying yes'), contains('disappoint')),
      );
    });

    test('boosts prove enough read for matching text', () {
      final result = engine.build(
        latestEntry: _entry(
          'I kept working because stopping made me feel behind.',
        ),
        audienceWedge: AudienceWedge.proveEnough,
      );
      expect(result.reads.first.title.toLowerCase(), contains('prove'));
      expect(result.reads.first.title.toLowerCase(), contains('enough'));
    });

    test('does not force unsupported wedge read', () {
      final result = engine.build(
        latestEntry: _entry(
          'I kept working because stopping made me feel behind.',
        ),
        audienceWedge: AudienceWedge.sayingYesCapacity,
      );
      expect(result.reads.first.title.toLowerCase(), contains('prove'));
      expect(
        result.reads.first.title.toLowerCase(),
        isNot(contains('saying yes before')),
      );
    });
  });

  group('first insight sharpness', () {
    test('specificity rating stored', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      await FirstInsightSpecificityStore.save(
        FirstInsightSpecificityRating.tooGeneric,
      );
      expect(
        await FirstInsightSpecificityStore.latest(),
        FirstInsightSpecificityRating.tooGeneric,
      );
    });

    testWidgets('sharpness row copy avoids banned terms', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstInsightSharpnessRow(
              onYesSpecific: () {},
              onTooGeneric: () {},
              onWrongAngle: () {},
            ),
          ),
        ),
      );
      const banned = [
        'therapy',
        'coach',
        'diagnosis',
        'AI friend',
        'VoiceMemory',
      ];
      for (final s in [
        ConsumerUiCopy.firstInsightSharpnessQuestion,
        ConsumerUiCopy.firstInsightSharpnessYes,
        ConsumerUiCopy.firstInsightSharpnessTooGeneric,
        ConsumerUiCopy.firstInsightSharpnessWrongAngle,
      ]) {
        for (final word in banned) {
          expect(s.toLowerCase(), isNot(contains(word.toLowerCase())));
        }
      }
    });

    testWidgets('too generic opens clearer prompt', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostSaveInsightChoiceCard(
                pattern: _pattern(),
                entry: _entry(
                  'I said yes to help again because I did not want to disappoint them and now I feel pressure.',
                ),
                reflectionCount: 1,
                audienceWedge: AudienceWedge.sayingYesCapacity,
                onSaveSignal: (_) async {},
                onRecordNext: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(ConsumerUiCopy.postSaveInsightAbFeelsCloserA));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(
        find.text(ConsumerUiCopy.firstInsightSharpnessTooGeneric),
      );
      await tester.tap(
        find.text(ConsumerUiCopy.firstInsightSharpnessTooGeneric),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text(ConsumerUiCopy.firstInsightTooGenericPrompt),
        findsOneWidget,
      );
    });

    testWidgets('wrong angle opens alternatives', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostSaveInsightChoiceCard(
                pattern: _pattern(),
                entry: _entry(
                  'I said yes to help again because I did not want to disappoint them and now I feel pressure.',
                ),
                reflectionCount: 1,
                onSaveSignal: (_) async {},
                onRecordNext: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(ConsumerUiCopy.postSaveInsightAbFeelsCloserA));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(
        find.text(ConsumerUiCopy.firstInsightSharpnessWrongAngle),
      );
      await tester.tap(
        find.text(ConsumerUiCopy.firstInsightSharpnessWrongAngle),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(ConsumerUiCopy.postSaveInsightAlternativeTitle),
        findsOneWidget,
      );
    });
  });

  group('wedge diagnosis', () {
    const engine = RetentionDiagnosisV2Engine();

    test('audience not activated', () {
      final result = engine.diagnose(
        _diagInput(first: false, wedge: AudienceWedge.proveEnough),
      );
      expect(result.bottleneck, RetentionBottleneckV2.audienceNotActivated);
    });

    test('insight too generic', () {
      final result = engine.diagnose(
        _diagInput(rating: FirstInsightSpecificityRating.tooGeneric),
      );
      expect(result.bottleneck, RetentionBottleneckV2.insightTooGeneric);
    });

    test('wrong angle', () {
      final result = engine.diagnose(
        _diagInput(rating: FirstInsightSpecificityRating.wrongAngle),
      );
      expect(result.bottleneck, RetentionBottleneckV2.wrongAngle);
    });

    test('weak wedge fit', () {
      final result = engine.diagnose(
        _diagInput(
          wedge: AudienceWedge.sayingYesCapacity,
          lastReadId: 'prove_enough',
          entrySupports: true,
        ),
      );
      expect(result.bottleneck, RetentionBottleneckV2.weakWedgeFit);
    });
  });

  test('paywall copy aligned to continuity concept', () {
    expect(
      ConsumerUiCopy.paywallHeadline,
      contains('archive useful'),
    );
    expect(
      ConsumerUiCopy.paywallBullets.first,
      contains('keeps returning'),
    );
    expect(
      ConsumerUiCopy.paywallHeadline,
      isNot(contains('pattern memory growing')),
    );
  });
}
