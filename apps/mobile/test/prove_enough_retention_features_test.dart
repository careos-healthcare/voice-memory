import 'dart:io';

import 'package:archiveme_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_engine.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:archiveme_mobile/features/prove_enough/next_evidence_mission_engine.dart';
import 'package:archiveme_mobile/features/prove_enough/next_evidence_mission_model.dart';
import 'package:archiveme_mobile/features/prove_enough/next_evidence_mission_store.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_contradiction_model.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_contradiction_store.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_post_record_engine.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_post_record_model.dart';
import 'package:archiveme_mobile/features/signal_review/signal_review_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/product/loop_mode_copy.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/widgets/prove_enough/contradiction_capture_card.dart';
import 'package:archiveme_mobile/widgets/prove_enough/next_evidence_mission_card.dart';
import 'package:archiveme_mobile/widgets/prove_enough/prove_enough_retention_panel.dart';
import 'package:archiveme_mobile/widgets/record/post_save_insight_choice_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6),
    transcript: transcript,
    durationSeconds: 45,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

FirstSessionPattern _pattern() {
  return FirstSessionPattern(
    id: 'prove_test',
    createdAt: DateTime(2026, 6),
    title: 'Trying to prove enough',
    whyNoticed: 'Pressure language showed up.',
    watchForText: 'whether pressure keeps showing up',
    chips: const ['pressure', 'prove'],
    confidenceLabel: FirstSessionConfidenceLabel.early,
    sourceTextPreview: 'I kept going.',
    matchReason: 'Your words pointed toward pressure.',
    confidenceScore: 0.6,
    categoryId: 'prove_enough',
    category: FirstSessionPatternCategory.responsibility,
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<MobilePrefsStore> _openPrefs(String stamp) async {
  final path = '/tmp/vm_prove_retention_prefs_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  return MobilePrefsStore.open(path);
}

ProveEnoughPostRecordModel _postRecord({required String transcript}) {
  const postEngine = ProveEnoughPostRecordEngine();
  const loopEngine = LoopModeEngine();
  return postEngine.analyze(
    entryId: 'e-mission',
    transcript: transcript,
    interpretationReads: const [],
    activeLoop: loopEngine.activate(LoopModeIds.proveEnough),
  );
}

void main() {
  const missionEngine = NextEvidenceMissionEngine();

  group('NextEvidenceMissionEngine', () {
    test('mission generated after prove_enough entry', () {
      final postRecord = _postRecord(
        transcript:
            'I kept going because I felt behind and had to prove I was productive.',
      );
      final mission = missionEngine.fromPostRecord(postRecord: postRecord);

      expect(mission.mission, isNotEmpty);
      expect(mission.sourceEntryId, postRecord.entryId);
      expect(
        mission.mission,
        NextEvidenceMissionEngine.keepGoingAfterEnoughMission,
      );
    });

    test('mission changes based on rest guilt', () {
      final postRecord = _postRecord(
        transcript:
            'I stopped for a minute and felt guilt about rest. I thought I was being lazy and uncomfortable stopping when I should be doing more.',
      );
      final mission = missionEngine.fromPostRecord(postRecord: postRecord);

      expect(mission.kind, NextEvidenceMissionKind.restPossibleOrUnsafe);
      expect(
        mission.mission,
        NextEvidenceMissionEngine.restPossibleOrUnsafeMission,
      );
    });

    test('mission changes based on choice-heavy moment', () {
      final postRecord = _postRecord(
        transcript:
            'I wanted to finish this because I enjoyed the work and had a clear reason. I chose to stay because it felt meaningful and I was satisfied.',
      );
      final mission = missionEngine.fromPostRecord(postRecord: postRecord);

      expect(mission.kind, NextEvidenceMissionKind.pressureNotChoice);
    });

    test('weak transcript uses conservative mission', () {
      final postRecord = _postRecord(transcript: 'It was fine.');
      final mission = missionEngine.fromPostRecord(postRecord: postRecord);

      expect(
        mission.mission,
        NextEvidenceMissionEngine.stoppingFeelsBehindMission,
      );
    });
  });

  group('ProveEnoughContradictionStore', () {
    test('contradiction save works', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      final prefs = await _openPrefs(stamp);
      final store = ProveEnoughContradictionStore.forPrefs(prefs);

      final saved = await store.save(
        option: ProveEnoughContradictionOption.restedWithoutGuilt,
        journeyId: 'j-test',
        entryId: 'e-test',
      );

      expect(saved.label, 'I rested without guilt');
      final rows = await store.loadForJourney('j-test');
      expect(rows, hasLength(1));
      expect(
        rows.first.option,
        ProveEnoughContradictionOption.restedWithoutGuilt,
      );
    });

    test('contradiction affects review challenge evidence', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      final prefs = await _openPrefs(stamp);
      final store = ProveEnoughContradictionStore.forPrefs(prefs);

      await store.save(
        option: ProveEnoughContradictionOption.stoppedNothingBad,
        journeyId: 'j-review',
      );

      final review = SignalReview(
        id: 'sr1',
        journeyId: 'j-review',
        signalTitle: 'Trying to prove enough',
        reviewStatus: SignalReviewStatus.ready,
        evidenceCount: 3,
        whatRepeated: 'Pressure may be repeating.',
        whatChanged: 'Same pattern.',
        evidenceLines: const ['I kept going late.'],
        possibleContradictions: LoopModeCopy.reviewProveWrongProveEnough,
        whatToWatchNext: 'Watch stopping.',
        nextEvidencePrompt: 'Record stopping.',
        createdAt: DateTime(2026, 6, 3),
        updatedAt: DateTime(2026, 6, 3),
        loopModeId: LoopModeIds.proveEnough,
        whatWouldProveThisWrong: LoopModeCopy.reviewProveWrongProveEnough,
      );

      final enriched = await store.enrichReviewChallengeEvidence(review);
      expect(
        enriched.whatWouldProveThisWrong,
        contains('Captured: I stopped and nothing bad happened'),
      );
    });
  });

  group('NextEvidenceMissionStore', () {
    test('persists generated mission', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      final prefs = await _openPrefs(stamp);
      final store = NextEvidenceMissionStore.forPrefs(prefs);
      const mission = NextEvidenceMissionModel(
        mission: NextEvidenceMissionEngine.stoppingFeelsBehindMission,
        kind: NextEvidenceMissionKind.stoppingFeelsBehind,
        sourceEntryId: 'e1',
      );

      await store.save(mission);
      final loaded = await store.load();
      expect(loaded?.mission, mission.mission);
      expect(loaded?.sourceEntryId, 'e1');
    });
  });

  group('prove_enough retention UI', () {
    testWidgets('mission card renders and CTA is wired', (tester) async {
      const mission = NextEvidenceMissionModel(
        mission: NextEvidenceMissionEngine.pressureNotChoiceMission,
        kind: NextEvidenceMissionKind.pressureNotChoice,
      );

      await tester.binding.setSurfaceSize(const Size(390, 800));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: NextEvidenceMissionCard(mission: mission)),
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.byKey(const Key('next_evidence_mission_card')),
        findsOneWidget,
      );
      expect(find.text('Next evidence mission'), findsOneWidget);
      expect(find.text(mission.mission), findsOneWidget);
      expect(find.text('Record this when it happens'), findsOneWidget);
    });

    testWidgets('mission CTA routes to Record', (tester) async {
      const mission = NextEvidenceMissionModel(
        mission: NextEvidenceMissionEngine.stoppingFeelsBehindMission,
        kind: NextEvidenceMissionKind.stoppingFeelsBehind,
      );
      var routed = false;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const NextEvidenceMissionCard(mission: mission),
          ),
          GoRoute(
            path: '/record',
            builder: (context, state) {
              routed = true;
              return const Scaffold(body: Text('Record screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _pumpFrames(tester);

      await tester.tap(
        find.byKey(const Key('next_evidence_mission_record_cta')),
      );
      await _pumpFrames(tester);

      expect(routed, isTrue);
      expect(find.text('Record screen'), findsOneWidget);
    });

    testWidgets('contradiction save shows confirmation copy', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContradictionCaptureCard(
                journeyId: 'j-ui',
                entryId: 'e-ui',
              ),
            ),
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.byKey(const Key('contradiction_capture_card')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('contradiction_option_effort_chosen')),
      );
      await _pumpFrames(tester);

      expect(
        find.text('This challenges the proving-enough loop.'),
        findsOneWidget,
      );
      expect(find.text('The effort felt chosen'), findsWidgets);
    });

    testWidgets('retention panel renders from post-record model', (
      tester,
    ) async {
      final postRecord = _postRecord(
        transcript:
            'I kept going because stopping made me feel behind and I had to prove I was productive.',
      );

      await tester.binding.setSurfaceSize(const Size(390, 1400));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProveEnoughRetentionPanel(
                postRecordModel: postRecord,
                entryId: postRecord.entryId,
              ),
            ),
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.byKey(const Key('prove_enough_retention_panel')),
        findsOneWidget,
      );
      expect(find.text('Next evidence mission'), findsOneWidget);
      expect(find.text('Did this challenge the loop?'), findsOneWidget);
    });

    testWidgets('cards do not render for capacity_yes post-save', (
      tester,
    ) async {
      final capacityLoop = const LoopModeEngine().activate(
        LoopModeIds.capacityYes,
      );
      final entry = _entry(
        'e-capacity',
        'I said yes again even though I was already stretched thin.',
      );

      await tester.binding.setSurfaceSize(const Size(390, 1400));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostSaveInsightChoiceCard(
                pattern: _pattern(),
                entry: entry,
                activeLoop: capacityLoop,
                onSaveSignal: (_) async {},
                onRecordNext: () {},
              ),
            ),
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.byKey(const Key('prove_enough_retention_panel')),
        findsNothing,
      );
      expect(find.text('Next evidence mission'), findsNothing);
    });
  });
}