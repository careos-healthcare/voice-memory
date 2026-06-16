import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/prove_enough/next_evidence_mission_engine.dart';
import 'package:voicememory_mobile/features/prove_enough/next_evidence_mission_model.dart';
import 'package:voicememory_mobile/features/prove_enough/prove_enough_contradiction_model.dart';
import 'package:voicememory_mobile/features/prove_enough/prove_enough_evidence_trail_engine.dart';
import 'package:voicememory_mobile/features/prove_enough/prove_enough_evidence_trail_model.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_model.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/screens/prove_enough_evidence_trail_screen.dart';

import 'signal_review_engine_test.dart' show entry, journey;

Future<void> _pumpFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

ProveEnoughEvidenceTrail _sampleTrail({
  int supporting = 5,
  bool includeExtended = true,
}) {
  const engine = ProveEnoughEvidenceTrailEngine();
  final entries = <JournalEntry>[
    entry(
      'e0',
      'I kept working late because stopping made me feel behind and not enough.',
    ),
    entry(
      'e1',
      'I did more to prove I was productive even though I was tired and drained.',
    ),
    entry(
      'e2',
      'I pushed through more work because rest felt unsafe and I felt behind.',
    ),
    entry(
      'e3',
      'I compared myself to everyone else and kept going to catch up on unfinished work.',
    ),
    entry(
      'e4',
      'I tried to rest during quiet time but felt guilt about stopping and being lazy.',
    ),
    if (includeExtended)
      entry(
        'e5',
        'I wanted to finish because I enjoyed it and chose to stay with a clear reason.',
      ),
  ];

  return engine.build(
    entries: entries,
    journey: journey(
      supporting: supporting,
      contradicting: includeExtended ? const ['e5'] : const [],
    ),
    review: SignalReview(
      id: 'sr1',
      journeyId: 'j1',
      signalTitle: 'Trying to prove enough',
      reviewStatus: SignalReviewStatus.ready,
      evidenceCount: supporting,
      whatRepeated: 'Pressure may be repeating.',
      whatChanged: 'The same pressure to keep going may be repeating.',
      evidenceLines: const [],
      possibleContradictions: '',
      whatToWatchNext: '',
      nextEvidencePrompt: '',
      createdAt: DateTime(2026, 6, 3),
      updatedAt: DateTime(2026, 6, 3),
      loopModeId: 'prove_enough',
    ),
    contradictions: includeExtended
        ? [
            ProveEnoughContradictionRecord(
              id: 'c1',
              option: ProveEnoughContradictionOption.restedWithoutGuilt,
              savedAt: DateTime(2026, 6, 4),
              journeyId: 'j1',
              entryId: 'e5',
            ),
          ]
        : const [],
    latestMission: const NextEvidenceMissionModel(
      mission: NextEvidenceMissionEngine.stoppingFeelsBehindMission,
      kind: NextEvidenceMissionKind.stoppingFeelsBehind,
    ),
  );
}

void main() {
  const engine = ProveEnoughEvidenceTrailEngine();

  group('ProveEnoughEvidenceTrailEngine', () {
    test('classifies supporting moments by pressure language', () {
      final trail = engine.build(
        entries: [
          entry(
            'e1',
            'I kept going because I felt behind and had to prove I was productive.',
          ),
          entry(
            'e2',
            'I did more work because stopping felt like falling behind again.',
          ),
        ],
      );

      expect(trail.supportingMoments, isNotEmpty);
      expect(
        trail.supportingMoments.first.excerpt.toLowerCase(),
        contains('behind'),
      );
    });

    test('counts supporting moments across entries', () {
      final trail = _sampleTrail(supporting: 5);
      expect(trail.supportingMoments.length, greaterThanOrEqualTo(3));
      expect(trail.previewMoments, hasLength(3));
    });

    test('includes contradictions in trail', () {
      final trail = _sampleTrail();
      expect(trail.contradictionMoments, isNotEmpty);
    });

    test('includes rest guilt and trigger summary', () {
      final trail = _sampleTrail();
      expect(trail.restGuiltMoments, isNotEmpty);
      expect(
        trail.restGuiltMoments.any(
          (moment) =>
              moment.excerpt.toLowerCase().contains('rest') ||
              moment.excerpt.toLowerCase().contains('stopping'),
        ),
        isTrue,
      );
      expect(trail.triggerSummary, isNotEmpty);
    });

    test('includes choice moments and what changed', () {
      final trail = _sampleTrail();
      expect(trail.choiceMoments, isNotEmpty);
      expect(trail.whatChanged, contains('pressure'));
      expect(trail.latestMission, isNotEmpty);
    });

    test('evidence excerpts are not invented', () {
      const transcript =
          'I kept working late because stopping made me feel behind and not enough.';
      final trail = engine.build(entries: [entry('e1', transcript)]);

      expect(trail.supportingMoments, hasLength(1));
      expect(
        transcript.toLowerCase(),
        contains(
          trail.supportingMoments.first.excerpt.toLowerCase().split(' ').first,
        ),
      );
    });
  });

  group('ProveEnoughEvidenceTrailScreen', () {
    testWidgets('free user sees preview but locked full trail', (tester) async {
      final trail = _sampleTrail();

      await tester.binding.setSurfaceSize(const Size(390, 1200));
      await tester.pumpWidget(
        MaterialApp(
          home: ProveEnoughEvidenceTrailScreen(
            initialTrail: trail,
            initialEntitlements: PremiumEntitlements.free(),
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.text(ProveEnoughEvidenceTrail.screenTitle), findsOneWidget);
      expect(
        find.text(ProveEnoughEvidenceTrail.confirmedSectionTitle),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('prove_enough_trail_locked_card')),
        findsOneWidget,
      );
      expect(find.text(ProveEnoughEvidenceTrail.lockedTitle), findsOneWidget);
      expect(
        find.text(ProveEnoughEvidenceTrail.challengedSectionTitle),
        findsNothing,
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('Pro user sees full trail sections', (tester) async {
      final trail = engine.build(
        entries: [
          entry(
            'e0',
            'I kept working late because stopping made me feel behind and not enough.',
          ),
          entry(
            'e1',
            'I tried to rest during quiet time but felt guilt about stopping and being lazy.',
          ),
          entry(
            'e2',
            'I wanted to finish because I enjoyed it and chose to stay with a clear reason.',
          ),
        ],
        journey: journey(supporting: 2, contradicting: const ['e2']),
        review: SignalReview(
          id: 'sr1',
          journeyId: 'j1',
          signalTitle: 'Trying to prove enough',
          reviewStatus: SignalReviewStatus.ready,
          evidenceCount: 2,
          whatRepeated: 'Pressure may be repeating.',
          whatChanged: 'The same pressure to keep going may be repeating.',
          evidenceLines: const [],
          possibleContradictions: '',
          whatToWatchNext: '',
          nextEvidencePrompt: '',
          createdAt: DateTime(2026, 6, 3),
          updatedAt: DateTime(2026, 6, 3),
          loopModeId: 'prove_enough',
        ),
        contradictions: [
          ProveEnoughContradictionRecord(
            id: 'c1',
            option: ProveEnoughContradictionOption.restedWithoutGuilt,
            savedAt: DateTime(2026, 6, 4),
            journeyId: 'j1',
            entryId: 'e2',
          ),
        ],
        latestMission: const NextEvidenceMissionModel(
          mission: NextEvidenceMissionEngine.stoppingFeelsBehindMission,
          kind: NextEvidenceMissionKind.stoppingFeelsBehind,
        ),
      );

      await tester.binding.setSurfaceSize(const Size(390, 1600));
      await tester.pumpWidget(
        MaterialApp(
          home: ProveEnoughEvidenceTrailScreen(
            initialTrail: trail,
            initialEntitlements: const PremiumEntitlements(
              tier: BillingTier.pro,
              entitlementIds: ['pro'],
              billingConnected: true,
              source: 'test',
            ),
          ),
        ),
      );
      await _pumpFrames(tester);

      for (final title in [
        ProveEnoughEvidenceTrail.challengedSectionTitle,
        ProveEnoughEvidenceTrail.restGuiltSectionTitle,
        ProveEnoughEvidenceTrail.choiceSectionTitle,
        ProveEnoughEvidenceTrail.changedSectionTitle,
      ]) {
        await tester.scrollUntilVisible(find.text(title), 300);
        await _pumpFrames(tester, frames: 2);
        expect(find.text(title), findsOneWidget);
      }

      expect(
        find.byKey(const Key('prove_enough_trail_locked_card')),
        findsNothing,
      );
    });

    testWidgets('CTA routes to paywall', (tester) async {
      final trail = _sampleTrail();
      var routed = false;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ProveEnoughEvidenceTrailScreen(
              initialTrail: trail,
              initialEntitlements: PremiumEntitlements.free(),
              onSeePro: () => context.push('/subscription'),
            ),
          ),
          GoRoute(
            path: '/subscription',
            builder: (context, state) {
              routed = true;
              return const Scaffold(body: Text('Paywall screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _pumpFrames(tester);

      await tester.tap(find.byKey(const Key('prove_enough_trail_see_pro_cta')));
      await _pumpFrames(tester);

      expect(routed, isTrue);
      expect(find.text('Paywall screen'), findsOneWidget);
    });
  });
}
