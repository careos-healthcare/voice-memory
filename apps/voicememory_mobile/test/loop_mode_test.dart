import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/interpretation/interpretation_quality_engine.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_coordinator.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_engine.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:voicememory_mobile/features/retention/retention_diagnosis_v2_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/loop_mode_copy.dart';
import 'package:voicememory_mobile/screens/onboarding_loop_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/record/loop_mode_first_handoff_card.dart';

import 'signal_review_engine_test.dart' show journey;

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

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_loop_journal_$stamp.json',
    prefsPath: '/tmp/vm_loop_prefs_$stamp.json',
  );
}

void main() {
  group('loop mode store', () {
    test('selecting prove_enough stores active loop', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      await LoopModeCoordinator.activate(LoopModeIds.proveEnough);
      final loop = await LoopModeCoordinator.loadActive();
      expect(loop, isNotNull);
      expect(loop!.id, LoopModeIds.proveEnough);
      expect(loop.active, isTrue);
      expect(loop.title, LoopModeCopy.proveEnoughTitle);
      expect(loop.interpretationBiasTags, contains('prove'));
    });

    test('selecting capacity_yes stores active loop', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      await LoopModeCoordinator.activate(LoopModeIds.capacityYes);
      final loop = await LoopModeCoordinator.loadActive();
      expect(loop, isNotNull);
      expect(loop!.id, LoopModeIds.capacityYes);
      expect(loop.active, isTrue);
      expect(loop.title, contains('capacity'));
    });

    test('skipping stores not sure loop', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      await LoopModeCoordinator.activateNotSure();
      final loop = await LoopModeCoordinator.loadActive();
      expect(loop?.id, LoopModeIds.notSure);
    });
  });

  group('loop mode engine', () {
    const engine = LoopModeEngine();

    test('proving text ranks proving-enough read first', () {
      const interp = InterpretationQualityEngine();
      final loop = engine.activate(LoopModeIds.proveEnough);
      final result = interp.build(
        latestEntry: _entry(
          'I kept working late because stopping made me feel behind and not enough.',
        ),
        activeLoop: loop,
      );
      expect(result.reads, isNotEmpty);
      expect(
        result.reads.first.title.toLowerCase(),
        contains('prove'),
      );
    });

    test('unrelated text does not force prove_enough', () {
      const interp = InterpretationQualityEngine();
      final loop = engine.activate(LoopModeIds.proveEnough);
      final result = interp.build(
        latestEntry: _entry(
          'The weather was nice and I went for a walk in the park.',
        ),
        activeLoop: loop,
      );
      expect(result.loopUnsupported, isTrue);
      expect(result.clearerMomentTitle, LoopModeCopy.proveEnoughUnsupportedTitle);
    });

    test('capacity text ranks capacity read first', () {
      const interp = InterpretationQualityEngine();
      final loop = engine.activate(LoopModeIds.capacityYes);
      final result = interp.build(
        latestEntry: _entry(
          'I agreed to help again because I did not want to disappoint them.',
        ),
        activeLoop: loop,
      );
      expect(result.reads, isNotEmpty);
      expect(
        result.reads.first.title.toLowerCase(),
        anyOf(contains('saying yes'), contains('disappoint')),
      );
    });

    test('unrelated text does not force capacity read', () {
      const interp = InterpretationQualityEngine();
      final loop = engine.activate(LoopModeIds.capacityYes);
      final result = interp.build(
        latestEntry: _entry(
          'The weather was nice and I went for a walk in the park.',
        ),
        activeLoop: loop,
      );
      expect(result.loopUnsupported, isTrue);
      expect(result.clearerMomentTitle, LoopModeCopy.capacityUnsupportedTitle);
    });

    test('progress status transitions', () {
      final loop = engine.activate(LoopModeIds.capacityYes).copyWith(
        completedRecordingCount: 0,
      );
      expect(engine.progressStatus(loop), LoopProgressStatus.lookingForFirstEvidence);
      expect(
        engine.progressStatus(loop.copyWith(completedRecordingCount: 2)),
        LoopProgressStatus.gettingClearer,
      );
    });
  });

  group('loop diagnosis', () {
    const diag = RetentionDiagnosisV2Engine();

    test('loop not activated', () {
      final result = diag.diagnose(
        RetentionDiagnosisV2Input(
          firstMomentRecorded: false,
          secondMomentRecorded: false,
          thirdMomentRecorded: false,
          interpretationSignals: const [],
          reminderPrePromptShown: false,
          reminderPrePromptAccepted: false,
          reminderPrePromptDismissed: 0,
          reminderReturnCount: 0,
          onboardingIntent: null,
          journeyEvidenceCount: 0,
          reviewConfirmed: false,
          loopModeSelected: LoopModeIds.capacityYes,
        ),
      );
      expect(result.bottleneck, RetentionBottleneckV2.loopNotActivated);
    });

    test('prove_enough not activated', () {
      final result = diag.diagnose(
        RetentionDiagnosisV2Input(
          firstMomentRecorded: false,
          secondMomentRecorded: false,
          thirdMomentRecorded: false,
          interpretationSignals: const [],
          reminderPrePromptShown: false,
          reminderPrePromptAccepted: false,
          reminderPrePromptDismissed: 0,
          reminderReturnCount: 0,
          onboardingIntent: null,
          journeyEvidenceCount: 0,
          reviewConfirmed: false,
          loopModeSelected: LoopModeIds.proveEnough,
        ),
      );
      expect(result.bottleneck, RetentionBottleneckV2.loopNotActivated);
    });

    test('loop unsupported recording', () {
      final result = diag.diagnose(
        RetentionDiagnosisV2Input(
          firstMomentRecorded: true,
          secondMomentRecorded: false,
          thirdMomentRecorded: false,
          interpretationSignals: const [],
          reminderPrePromptShown: false,
          reminderPrePromptAccepted: false,
          reminderPrePromptDismissed: 0,
          reminderReturnCount: 0,
          onboardingIntent: null,
          journeyEvidenceCount: 1,
          reviewConfirmed: false,
          loopModeSelected: LoopModeIds.capacityYes,
          loopUnsupportedRecording: true,
        ),
      );
      expect(
        result.bottleneck,
        RetentionBottleneckV2.loopUnsupportedByRecording,
      );
    });
  });

  testWidgets('onboarding loop copy avoids banned terms', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingLoopScreen()),
    );
    const banned = ['therapy', 'coach', 'diagnosis', 'AI friend', 'VoiceMemory'];
    for (final s in [
      LoopModeCopy.onboardingTitle,
      LoopModeCopy.capacityHandoffTitle,
      LoopModeCopy.capacityPostSaveTitle,
    ]) {
      for (final word in banned) {
        expect(s.toLowerCase(), isNot(contains(word.toLowerCase())));
      }
    }
  });

  testWidgets('prove_enough changes first handoff copy', (tester) async {
    const engine = LoopModeEngine();
    final loop = engine.activate(LoopModeIds.proveEnough);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoopModeFirstHandoffCard(
            loop: loop,
            onStartRecording: () {},
          ),
        ),
      ),
    );
    expect(find.text(LoopModeCopy.proveEnoughHandoffTitle), findsOneWidget);
    expect(find.text(LoopModeCopy.proveEnoughHandoffPrompt), findsOneWidget);
    expect(find.text(LoopModeCopy.proveEnoughHandoffCta), findsOneWidget);
  });

  testWidgets('active loop changes first handoff copy', (tester) async {
    const engine = LoopModeEngine();
    final loop = engine.activate(LoopModeIds.capacityYes);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoopModeFirstHandoffCard(
            loop: loop,
            onStartRecording: () {},
          ),
        ),
      ),
    );
    expect(find.text(LoopModeCopy.capacityHandoffTitle), findsOneWidget);
    expect(find.text(LoopModeCopy.capacityHandoffPrompt), findsOneWidget);
    expect(find.text(LoopModeCopy.capacityHandoffCta), findsOneWidget);
  });

  test('reminder notification copy has no transcript', () {
    expect(
      LoopModeCopy.capacityReminderNotificationBody,
      isNot(contains('disappoint')),
    );
    expect(LoopModeCopy.capacityReminderNotificationTitle, isNotEmpty);
    expect(
      LoopModeCopy.proveEnoughReminderNotificationBody,
      isNot(contains('behind')),
    );
    expect(LoopModeCopy.proveEnoughReminderNotificationTitle, isNotEmpty);
  });

  test('prove journey copy is loop-specific', () {
    const engine = LoopModeEngine();
    final loop = engine.activate(LoopModeIds.proveEnough);
    expect(engine.journeyTitle(loop), LoopModeCopy.proveEnoughJourneyTitle);
    expect(engine.journeyProgressLabel(loop, journey(supporting: 2)),
        LoopModeCopy.proveEnoughProgress(2));
    expect(
      LoopModeCopy.proveEnoughNextPrompts,
      contains(engine.nextPrompt(loop)),
    );
  });

  test('paywall after loop copy aligned', () {
    expect(LoopModeCopy.paywallAfterLoopHeadline, contains('loop'));
    expect(
      LoopModeCopy.paywallAfterLoopBullets.first,
      contains('yes-before-capacity'),
    );
    expect(LoopModeCopy.paywallAfterLoopBody, contains('evidence trail'));
  });
}
