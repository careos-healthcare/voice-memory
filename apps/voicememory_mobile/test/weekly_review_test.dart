import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/changes/change_resurfacing.dart';
import 'package:voicememory_mobile/features/changes/change_thread_projection.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_review.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_review_access.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_review_engine.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_review_entry_card.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_review_notification.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_review_screen.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_review_store.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_review_sufficiency.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

const _pro = EntitlementSnapshot(
  plan: PlanKind.pro,
  status: EntitlementStatus.active,
);
const _serverMetered = UsageSnapshot.serverAuthoritative();

void main() {
  final now = DateTime.utc(2026, 7, 8, 12);

  // Two separate threads in one week: a garden pattern that came up again, and
  // a work response whose wording moved from certain to uncertain.
  final repeatOne = _entry('r1', 'I paused before the garden watering.', 3);
  final repeatTwo = _entry('r2', 'I paused before another garden watering.', 4);
  final calm = _entry('w1', 'My work response felt calm and certain.', 5);
  final worried = _entry(
    'w2',
    'My work response felt worried and uncertain.',
    6,
  );
  final entries = [repeatOne, repeatTwo, calm, worried];
  final conclusions = [
    _conclusion(
      id: 'garden-repeat',
      kind: ExplainableInsightKind.pattern,
      statement: 'Pausing before the garden watering may be repeating.',
      evidence: [
        _citation(repeatOne, temporalRole: EvidenceTemporalRole.then),
        _citation(repeatTwo, temporalRole: EvidenceTemporalRole.now),
      ],
    ),
    _conclusion(
      id: 'work-weaken',
      kind: ExplainableInsightKind.change,
      statement: 'Your work response wording moved from certain to uncertain.',
      evidence: [
        _citation(calm, temporalRole: EvidenceTemporalRole.then),
        _citation(worried, temporalRole: EvidenceTemporalRole.now),
      ],
    ),
  ];

  ChangeThreadProjection projectionOf(List<JournalEntry> source) =>
      ChangeThreadProjector.project(
        archiveId: 'local',
        entries: source,
        conclusions: conclusions,
      );

  ChangeResurfacingContext archiveOf(
    List<JournalEntry> source, {
    DateTime? at,
  }) => ChangeResurfacingContext.fromEntries(source, now: at ?? now);

  WeeklyReviewOutcome build({
    List<JournalEntry>? source,
    DateTime? at,
    EntitlementSnapshot entitlement = _pro,
    UsageSnapshot usage = _serverMetered,
  }) {
    final resolved = source ?? entries;
    return WeeklyReviewEngine.build(
      projection: projectionOf(resolved),
      archive: archiveOf(resolved, at: at),
      entitlement: entitlement,
      usage: usage,
    );
  }

  group('the sufficiency bar', () {
    test('is stated as numbers, not a feeling', () {
      expect(WeeklyReviewSufficiency.window, const Duration(days: 7));
      expect(WeeklyReviewSufficiency.minimumDistinctSavedMoments, 3);
      expect(WeeklyReviewSufficiency.minimumDistinctDays, 2);
      expect(WeeklyReviewSufficiency.minimumItems, 2);
    });

    test('names the first unmet condition', () {
      expect(
        WeeklyReviewSufficiency.shortfall(
          const WeeklyReviewEvidence(
            distinctSavedMoments: 2,
            distinctDays: 2,
            itemCount: 2,
          ),
        ),
        WeeklyReviewShortfall.tooFewSavedMoments,
      );
      expect(
        WeeklyReviewSufficiency.shortfall(
          const WeeklyReviewEvidence(
            distinctSavedMoments: 4,
            distinctDays: 1,
            itemCount: 2,
          ),
        ),
        WeeklyReviewShortfall.tooFewDays,
      );
      expect(
        WeeklyReviewSufficiency.shortfall(
          const WeeklyReviewEvidence(
            distinctSavedMoments: 4,
            distinctDays: 3,
            itemCount: 1,
          ),
        ),
        WeeklyReviewShortfall.tooFewItems,
      );
      expect(
        WeeklyReviewSufficiency.isSufficient(
          const WeeklyReviewEvidence(
            distinctSavedMoments: 3,
            distinctDays: 2,
            itemCount: 2,
          ),
        ),
        isTrue,
      );
    });

    test('is not an entry-count milestone', () {
      // A long archive of moments that produced no findings this week is still
      // not a week worth summarising.
      final many = [
        for (var day = 1; day <= 200; day++)
          _entry('bulk-$day', 'I noticed the weather outside.', 1),
      ];
      expect(build(source: many).hasReview, isFalse);
    });
  });

  group('generating a review', () {
    test('reports exactly what the threads show, and stops', () {
      final review = build().review;

      expect(review, isNotNull);
      expect(
        review!.headline,
        'This week, one pattern repeated and one may be weakening.',
      );
      expect(review.items.map((item) => item.kind), [
        WeeklyReviewItemKind.repeated,
        WeeklyReviewItemKind.weakened,
      ]);
      expect(review.evidenceSummary, 'two items · four saved moments');
    });

    test('every item links to exact evidence and back into Changes', () {
      final review = build().review!;
      final threadIds = projectionOf(
        entries,
      ).threads.map((view) => view.thread.threadId).toSet();
      final transcripts = {for (final entry in entries) entry.transcript};

      for (final item in review.items) {
        expect(item.threadId, isNotEmpty, reason: item.kind.name);
        expect(threadIds, contains(item.threadId), reason: item.kind.name);
        expect(item.evidence, isNotEmpty, reason: item.kind.name);
        for (final citation in item.evidence) {
          expect(citation.entryId, isNotEmpty);
          expect(transcripts, contains(citation.quote));
          expect(citation.sourceCapturedAt, isNotNull);
        }
      }
    });

    test('withholds a review when only one thread has anything to say', () {
      final outcome = build(source: [repeatOne, repeatTwo]);

      expect(outcome.hasReview, isFalse);
      // Two moments on one thread fails the moment bar before the item bar.
      expect(outcome.shortfall, WeeklyReviewShortfall.tooFewSavedMoments);
    });

    test('withholds a review when the findings are older than the window', () {
      final outcome = build(at: DateTime.utc(2026, 8, 8));

      expect(outcome.hasReview, isFalse);
      expect(outcome.shortfall, WeeklyReviewShortfall.tooFewSavedMoments);
    });

    test('leaves out moments the user asked not to be surfaced', () {
      final guarded = [
        repeatOne,
        repeatTwo,
        calm,
        _entry(
          worried.id,
          worried.transcript,
          6,
          memorySurfacing: MemorySurfacingMode.sensitive.id,
        ),
      ];
      final outcome = build(source: guarded);

      // Dropping that moment drops the change it belonged to, and the week no
      // longer clears the bar on its own.
      expect(outcome.hasReview, isFalse);
      expect(outcome.shortfall, WeeklyReviewShortfall.tooFewSavedMoments);
    });

    test('leaves out moments whose source no longer exists', () {
      final deleted = [
        repeatOne,
        repeatTwo,
        calm,
        worried.copyWith(deletedAt: DateTime.utc(2026, 7, 7)),
      ];

      expect(build(source: deleted).hasReview, isFalse);
    });

    test('one week produces one stable review id', () {
      expect(build().review!.reviewId, 'weekly_review_2026_07_08');
      expect(build().review!.reviewId, build().review!.reviewId);
    });

    test('says nothing encouraging, advisory, or congratulatory', () {
      final review = build().review!;
      final spoken = [
        review.headline,
        review.evidenceSummary,
        for (final item in review.items) ...[
          item.kind.label,
          item.statement,
          item.threadLabel,
        ],
        WeeklyReviewCopy.entryPointTitle,
        WeeklyReviewCopy.screenTitle,
        WeeklyReviewCopy.evidenceHeading,
        WeeklyReviewCopy.openThreadCta,
        WeeklyReviewCopy.openMomentCta,
        WeeklyReviewCopy.notificationOptInLabel,
        WeeklyReviewCopy.notificationOptInHelper,
      ].join(' ').toLowerCase();

      for (final banned in [
        'you should',
        'try to',
        'keep going',
        'keep it up',
        'well done',
        'great work',
        'proud',
        'progress',
        'streak',
        'milestone',
        'goal',
        'framework',
        'journey',
      ]) {
        expect(spoken.contains(banned), isFalse, reason: banned);
      }
    });
  });

  group('entitlement', () {
    test('new generation follows the periodic-review policy', () {
      final outcome = build(entitlement: const EntitlementSnapshot.free());

      expect(outcome.hasReview, isFalse);
      expect(outcome.shortfall, WeeklyReviewShortfall.generationNotPermitted);
    });

    test('an exhausted allowance stops generation too', () {
      final outcome = build(
        usage: const UsageSnapshot(
          used: {UsageMeterId.periodicReview: 1},
          allowances: {UsageMeterId.periodicReview: 1},
        ),
      );

      expect(outcome.shortfall, WeeklyReviewShortfall.generationNotPermitted);
    });

    test('a review already generated stays readable after expiry', () {
      const expired = EntitlementSnapshot(
        plan: PlanKind.free,
        status: EntitlementStatus.expired,
      );

      expect(
        WeeklyReviewAccess.generation(entitlement: expired).allowed,
        isFalse,
      );
      expect(WeeklyReviewAccess.reading(entitlement: expired).allowed, isTrue);
    });
  });

  group('notifications', () {
    test('stay off until the user turns them on', () {
      expect(WeeklyReviewNotificationPolicy.defaultOptedIn, isFalse);
      expect(
        WeeklyReviewNotificationPolicy.notificationFor(
          review: build().review,
          userOptedIn: false,
        ),
        isNull,
      );
    });

    test('carry no journal text', () {
      final review = build().review!;
      final notification = WeeklyReviewNotificationPolicy.notificationFor(
        review: review,
        userOptedIn: true,
      );

      expect(notification, isNotNull);
      expect(notification!.body, 'Open ArchiveMe when you want to look.');
      expect(
        WeeklyReviewNotificationPolicy.carriesNoJournalText(
          notification,
          review,
        ),
        isTrue,
      );
      for (final entry in entries) {
        expect(notification.body, isNot(contains(entry.transcript)));
        expect(notification.title, isNot(contains(entry.transcript)));
      }
    });

    test('fire once per review', () {
      final review = build().review!;

      expect(
        WeeklyReviewNotificationPolicy.notificationFor(
          review: review,
          userOptedIn: true,
          lastNotifiedReviewId: review.reviewId,
        ),
        isNull,
      );
    });
  });

  group('WeeklyReviewStore', () {
    late Directory directory;
    late List<int> sharedKey;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('weekly_review_test_');
      sharedKey = List<int>.generate(32, (index) => index + 7);
    });

    tearDown(() => directory.delete(recursive: true));

    WeeklyReviewStore open({String archiveId = 'local'}) => WeeklyReviewStore(
      file: File('${directory.path}/weekly_review.enc'),
      keyStore: InMemoryPrivateDataEncryptionKeyStore(seedKey: sharedKey),
      archiveId: archiveId,
    );

    test('a generated review stays readable after a restart', () async {
      final review = build().review!;
      await open().saveReview(review);

      final reopened = (await open().read()).review;

      expect(reopened, isNotNull);
      expect(reopened!.reviewId, review.reviewId);
      expect(reopened.headline, review.headline);
      expect(reopened.items, hasLength(review.items.length));
      expect(
        reopened.items.first.evidence.first.quote,
        review.items.first.evidence.first.quote,
      );
    });

    test('the opt-in is remembered and archive scoped', () async {
      await open().setNotificationOptIn(true);
      await open().saveReview(build().review!);

      expect((await open().read()).notificationOptedIn, isTrue);
      final other = await open(archiveId: 'other-account').read();
      expect(other.notificationOptedIn, isFalse);
      expect(other.review, isNull);
    });
  });

  group('the weekly review surfaces', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: child));
      await tester.pumpAndSettle();
    }

    testWidgets('the entry point is one card, not a tab', (tester) async {
      var opened = 0;
      await pump(
        tester,
        Scaffold(
          body: WeeklyReviewEntryCard(
            review: build().review!,
            onOpen: () => opened++,
          ),
        ),
      );

      expect(
        find.text('This week, one pattern repeated and one may be weakening.'),
        findsOneWidget,
      );
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.byKey(const Key('weekly_review_entry_card')));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('every item shows its words and opens its thread', (
      tester,
    ) async {
      final review = build().review!;
      final openedThreads = <String>[];
      final openedMoments = <String>[];

      await pump(
        tester,
        WeeklyReviewScreen(
          review: review,
          onOpenThread: openedThreads.add,
          onOpenMoment: (citation) => openedMoments.add(citation.entryId),
        ),
      );

      expect(find.text('Came up again'), findsOneWidget);
      expect(find.text('May be easing off'), findsOneWidget);
      expect(find.text('“${calm.transcript}”'), findsOneWidget);
      expect(find.text('“${worried.transcript}”'), findsOneWidget);
      expect(
        find.text(WeeklyReviewCopy.openThreadCta),
        findsNWidgets(review.items.length),
      );

      await tester.tap(find.text(WeeklyReviewCopy.openThreadCta).first);
      await tester.pumpAndSettle();
      expect(openedThreads, [review.items.first.threadId]);

      await tester.tap(
        find.textContaining(WeeklyReviewCopy.openMomentCta).first,
      );
      await tester.pumpAndSettle();
      expect(openedMoments, isNotEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}

JournalEntry _entry(
  String id,
  String transcript,
  int day, {
  String memorySurfacing = 'normal',
}) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 7, day),
  transcript: transcript,
  durationSeconds: 0,
  source: SavedMomentSource.typed,
  memorySurfacing: memorySurfacing,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

TranscriptEvidenceCitation _citation(
  JournalEntry entry, {
  EvidenceTemporalRole temporalRole = EvidenceTemporalRole.single,
}) => TranscriptEvidenceCitation(
  entryId: entry.id,
  quote: entry.transcript,
  startUtf16: 0,
  endUtf16: entry.transcript.length,
  role: TranscriptEvidenceRole.supporting,
  sourceCapturedAt: entry.createdAt,
  sourceType: EvidenceSourceType.text,
  temporalRole: temporalRole,
);

ExplainableConclusion _conclusion({
  required String id,
  required ExplainableInsightKind kind,
  required String statement,
  required List<TranscriptEvidenceCitation> evidence,
}) => ExplainableConclusion(
  id: id,
  kind: kind,
  statement: statement,
  confidence: 75,
  reasoning: const ['The exact saved wording supports this narrow claim.'],
  uncertaintyNote: 'Later saved moments may support or challenge this read.',
  evidence: evidence,
  alternatives: const [
    ExplainableAlternative(
      statement: 'The circumstances may explain this wording.',
      rationale: 'More saved moments could support a different explanation.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'test',
    generatedAt: DateTime.utc(2026, 7, 7),
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
);
