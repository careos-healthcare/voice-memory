import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:voicememory_mobile/features/archive_discovery_share/archive_discovery_share_card_model.dart';
import 'package:voicememory_mobile/features/archive_discovery_share/archive_discovery_share_copy.dart';
import 'package:voicememory_mobile/features/archive_discovery_share/archive_discovery_share_engine.dart';
import 'package:voicememory_mobile/features/archive_discovery_share/archive_discovery_share_moments.dart';
import 'package:voicememory_mobile/features/archive_discovery_share/archive_discovery_share_palette.dart';
import 'package:voicememory_mobile/features/archive_discovery_share/archive_discovery_share_types.dart';
import 'package:voicememory_mobile/features/archive_surprises/archive_surprises_models.dart';
import 'package:voicememory_mobile/features/archive_synthesis/archive_synthesis_models.dart';
import 'package:voicememory_mobile/features/archive_theory/archive_theory_models.dart';
import 'package:voicememory_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_models.dart';
import 'package:voicememory_mobile/features/belief_lifecycle/belief_lifecycle_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/widgets/archive_discovery_share/archive_discovery_share_card.dart';
import 'package:voicememory_mobile/widgets/archive_discovery_share/share_discovery_button.dart';

JournalEntry _entry(
  String id,
  DateTime at, {
  List<String> themes = const ['work'],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: 'Reflection text long enough for evidence eligibility here.',
    durationSeconds: 20,
    reflection: Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: themes,
      exactLanguagePattern: '',
      concreteObservation: 'I am uncertain about this decision today.',
      repeatedSignal: 'pressure',
    ),
  );
}

ArchiveV1View _minimalV1({
  List<ArchiveV1Contradiction> contradictions = const [],
  ArchiveChangeFeedView? changeFeed,
  ArchiveV1ThenNow? thenNow,
}) {
  return ArchiveV1View(
    hasMinimumEvidence: true,
    belief: null,
    theory: const ArchiveCurrentTheory(
      statement: 'Work dominates my week.',
      confidencePercent: 55,
      evidenceCount: 8,
      counterEvidenceCount: 1,
      lastUpdated: null,
      isConfident: true,
      missingEvidenceMessage: '',
      strengthenEvidenceLines: [],
    ),
    theoryRanking: null,
    thenNow: thenNow,
    contradictions: contradictions,
    blindSpots: const [],
    evolutionTimeline: const BeliefEvolutionTimeline(
      blocks: [],
      firstBelief: null,
      currentBelief: null,
    ),
    lifecycle: const BeliefLifecycleView(current: null, retired: []),
    changeFeed: changeFeed ?? ArchiveChangeFeedView.empty,
    surprises: ArchiveSurprisesView.empty,
    eligibleEntries: const [],
  );
}

void main() {
  group('ArchiveDiscoveryShareCardType', () {
    test('V2 analytics values', () {
      expect(
        ArchiveDiscoveryShareCardType.beliefLifecycle.analyticsValue,
        'belief_lifecycle',
      );
      expect(
        ArchiveDiscoveryShareCardType.monthlyReviewInsight.analyticsValue,
        'monthly_review_insight',
      );
      expect(
        ArchiveDiscoveryShareCardType.surpriseObservation.analyticsValue,
        'surprise_observation',
      );
    });
  });

  group('ArchiveDiscoveryShareCopy', () {
    test('evidence line pluralizes', () {
      expect(ArchiveDiscoveryShareCopy.evidenceLine(1), 'Based on 1 recording');
      expect(
        ArchiveDiscoveryShareCopy.evidenceLine(3),
        'Based on 3 recordings',
      );
      expect(
        ArchiveDiscoveryShareCopy.evidenceLine(0),
        'Based on your recordings',
      );
    });
  });

  group('ArchiveDiscoveryShareMoments', () {
    test('fromContradiction uses entry count', () {
      final card = ArchiveDiscoveryShareMoments.fromContradiction(
        const ArchiveV1Contradiction(
          id: 'c1',
          youSay: 'I am calm',
          but: 'recordings show stress',
          confidenceScore: 80,
          entryIds: ['a', 'b'],
        ),
      );
      expect(card, isNotNull);
      expect(card!.type, ArchiveDiscoveryShareCardType.contradiction);
      expect(card.evidenceRecordingCount, 2);
      expect(card.insight, contains('calm'));
    });

    test('fromThenNow requires distinct evolution', () {
      expect(
        ArchiveDiscoveryShareMoments.fromThenNow(
          const ArchiveV1ThenNow(
            thenBelief: 'old',
            nowBelief: 'new',
            firstEvidenceAt: null,
            latestEvidenceAt: null,
            supportingEvidenceCount: 5,
            hasDistinctEvolution: false,
          ),
        ),
        isNull,
      );
      final card = ArchiveDiscoveryShareMoments.fromThenNow(
        const ArchiveV1ThenNow(
          thenBelief: 'I need rest',
          nowBelief: 'Rest is non-negotiable',
          firstEvidenceAt: null,
          latestEvidenceAt: null,
          supportingEvidenceCount: 5,
          hasDistinctEvolution: true,
        ),
      );
      expect(card?.evidenceRecordingCount, 5);
      expect(card?.type, ArchiveDiscoveryShareCardType.beliefChange);
    });

    test('fromSurprise maps observation', () {
      final card = ArchiveDiscoveryShareMoments.fromSurprise(
        const ArchiveSurpriseObservation(
          id: 's1',
          kind: ArchiveSurpriseKind.themeDominanceGap,
          observation: 'You mention work far more than you claim.',
          evidenceCount: 4,
          evidenceEntryIds: [],
          confidenceScore: 70,
        ),
      );
      expect(card?.type, ArchiveDiscoveryShareCardType.surpriseObservation);
      expect(card?.evidenceRecordingCount, 4);
    });

    test('lifecycle shareable when weakening', () {
      final entry = BeliefLifecycleEntry(
        statement: 'I can handle anything',
        status: BeliefLifecycleStatus.weakening,
        firstSeen: DateTime(2026, 1, 1),
        lastSeen: DateTime(2026, 3, 1),
        isActiveInArchive: true,
        events: const [],
      );
      expect(ArchiveDiscoveryShareMoments.isLifecycleShareable(entry), isTrue);
      expect(ArchiveDiscoveryShareMoments.fromLifecycleEntry(entry), isNotNull);
    });
  });

  group('ArchiveDiscoveryShareEngine', () {
    test('builds milestone card at 50 recordings', () {
      final entries = List.generate(
        50,
        (i) => _entry('e$i', DateTime(2026, 1, i + 1)),
      );
      final cards = ArchiveDiscoveryShareEngine.build(entries: entries);
      expect(
        cards.any((c) => c.type == ArchiveDiscoveryShareCardType.milestone),
        isTrue,
      );
      final milestone = cards.firstWhere(
        (c) => c.type == ArchiveDiscoveryShareCardType.milestone,
      );
      expect(milestone.evidenceRecordingCount, 50);
    });

    test('builds pattern discovery from recurring themes', () {
      final entries = List.generate(
        5,
        (i) => _entry('e$i', DateTime(2026, 1, i + 1), themes: ['burnout']),
      );
      final cards = ArchiveDiscoveryShareEngine.build(entries: entries);
      expect(
        cards.any(
          (c) => c.type == ArchiveDiscoveryShareCardType.patternDiscovery,
        ),
        isTrue,
      );
    });

    test('builds change detected from theme shift', () {
      final entries = List.generate(
        5,
        (i) => _entry('e$i', DateTime(2026, 1, i + 1)),
      );
      final cards = ArchiveDiscoveryShareEngine.build(
        entries: entries,
        archiveV1: _minimalV1(
          changeFeed: ArchiveChangeFeedView(
            hasBaseline: true,
            reviewedAt: DateTime(2026, 4, 1),
            newReflectionCount: 1,
            beliefsStrengthened: const [],
            beliefsWeakened: const [],
            contradictionsAppeared: const [],
            contradictionsResolved: const [],
            themesIncreasing: const [
              ArchiveChangeThemeRow(
                label: 'anxiety',
                mentionSeries: [1, 2, 4],
                mentionsAtReview: 2,
                mentionsNow: 4,
                newMentionsSinceReview: 2,
              ),
            ],
            themesDecreasing: const [],
          ),
        ),
      );
      expect(
        cards.any(
          (c) => c.type == ArchiveDiscoveryShareCardType.changeDetected,
        ),
        isTrue,
      );
    });
  });

  group('ArchiveDiscoverySharePalette', () {
    test('light and dark palettes differ', () {
      final light = ArchiveDiscoverySharePalette.fromBrightness(
        Brightness.light,
      );
      final dark = ArchiveDiscoverySharePalette.fromBrightness(Brightness.dark);
      expect(light.background, isNot(dark.background));
      expect(light.insight, isNot(dark.insight));
    });
  });

  group('ArchiveDiscoveryShareCard', () {
    testWidgets('renders intro, insight, evidence, and footer', (tester) async {
      const card = ArchiveDiscoveryShareCardModel(
        id: 'test-1',
        type: ArchiveDiscoveryShareCardType.beliefChange,
        insight: 'A belief is fading: I need more rest.',
        evidenceRecordingCount: 6,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ArchiveDiscoveryShareCard(card: card)),
        ),
      );

      expect(find.text(ArchiveDiscoveryShareCopy.introLine), findsOneWidget);
      expect(find.text(card.insight), findsOneWidget);
      expect(find.text('Based on 6 recordings'), findsOneWidget);
      expect(find.text(ArchiveDiscoveryShareCopy.footer), findsOneWidget);
      expect(
        find.byKey(const Key('archive_discovery_share_card')),
        findsOneWidget,
      );
    });

    testWidgets('dark theme uses dark palette', (tester) async {
      const card = ArchiveDiscoveryShareCardModel(
        id: 'dark-1',
        type: ArchiveDiscoveryShareCardType.contradiction,
        insight: 'Test insight',
        evidenceRecordingCount: 2,
      );
      final palette = ArchiveDiscoverySharePalette.fromBrightness(
        Brightness.dark,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ArchiveDiscoveryShareCard(card: card, palette: palette),
          ),
        ),
      );

      final insightFinder = find.byKey(
        const Key('archive_discovery_share_insight'),
      );
      final style = tester.widget<Text>(insightFinder).style;
      expect(style?.color, palette.insight);
    });
  });

  group('ShareDiscoveryButton', () {
    testWidgets('shows Share Discovery label', (tester) async {
      const card = ArchiveDiscoveryShareCardModel(
        id: 'btn-1',
        type: ArchiveDiscoveryShareCardType.surpriseObservation,
        insight: 'Surprise text',
        evidenceRecordingCount: 3,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShareDiscoveryButton(card: card, surface: 'test_surface'),
          ),
        ),
      );

      expect(
        find.text(ArchiveDiscoveryShareCopy.shareDiscoveryLabel),
        findsOneWidget,
      );
    });
  });
}
