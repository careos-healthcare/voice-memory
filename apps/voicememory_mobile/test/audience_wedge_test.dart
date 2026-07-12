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
import 'package:voicememory_mobile/product/loop_mode_copy.dart';
import 'package:voicememory_mobile/screens/onboarding_intent_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/record/first_insight_sharpness_row.dart';
import 'package:voicememory_mobile/widgets/record/post_save_clearer_moment_banner.dart';

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
      expect(find.text('Saying yes with no capacity'), findsOneWidget);
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
      expect(
        AudienceWedge.sayingYesCapacity.firstPrompt,
        LoopModeCopy.capacityHandoffPrompt,
      );
      expect(
        AudienceWedge.proveEnough.firstPrompt.toLowerCase(),
        contains('pressure to do more'),
      );
      expect(
        AudienceWedge.notSureYet.firstPrompt.toLowerCase(),
        contains('pressure to do more'),
      );
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
      final title = result.reads.first.title.toLowerCase();
      expect(title, isNot(contains('saying yes before')));
      expect(
        title,
        anyOf(contains('prove'), contains('ignoring rest')),
      );
    });
  });

  group('first insight sharpness', () {
    setUp(() async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
    });

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

    test('too generic specificity rating stored', () async {
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

    testWidgets('too generic clearer prompt copy renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostSaveClearerMomentBanner(
              prompt: ConsumerUiCopy.firstInsightTooGenericPrompt,
              onRecordNext: () {},
            ),
          ),
        ),
      );
      expect(
        find.text(ConsumerUiCopy.firstInsightTooGenericPrompt),
        findsOneWidget,
      );
    });

    testWidgets('sharpness row wires too generic callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstInsightSharpnessRow(
              onYesSpecific: () {},
              onTooGeneric: () => tapped = true,
              onWrongAngle: () {},
            ),
          ),
        ),
      );
      await tester.tap(
        find.text(ConsumerUiCopy.firstInsightSharpnessTooGeneric),
      );
      expect(tapped, isTrue);
    });

    test('wrong angle specificity rating stored', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      await FirstInsightSpecificityStore.save(
        FirstInsightSpecificityRating.wrongAngle,
      );
      expect(
        await FirstInsightSpecificityStore.latest(),
        FirstInsightSpecificityRating.wrongAngle,
      );
    });

    testWidgets('sharpness row wires wrong angle callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstInsightSharpnessRow(
              onYesSpecific: () {},
              onTooGeneric: () {},
              onWrongAngle: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(
        find.text(ConsumerUiCopy.firstInsightSharpnessWrongAngle),
      );
      expect(tapped, isTrue);
      expect(ConsumerUiCopy.postSaveInsightAlternativeTitle, isNotEmpty);
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
      contains('longer proof trail'),
    );
    expect(
      ConsumerUiCopy.paywallBullets.first,
      contains('Longer proof trail'),
    );
    expect(
      ConsumerUiCopy.paywallDifferentiation,
      contains('not more chat'),
    );
  });
}
