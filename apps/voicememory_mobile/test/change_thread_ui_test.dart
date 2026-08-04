import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/changes/change_evidence_visibility.dart';
import 'package:voicememory_mobile/features/changes/change_resurfacing.dart';
import 'package:voicememory_mobile/features/changes/change_review_history.dart';
import 'package:voicememory_mobile/features/changes/change_structured_markers.dart';
import 'package:voicememory_mobile/features/changes/change_thread.dart';
import 'package:voicememory_mobile/features/changes/change_thread_correction.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/change_dimensions.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:voicememory_mobile/screens/belief_changes_screen.dart';

void main() {
  const thenText = 'I answered the work message immediately.';
  const nowText = 'I paused before answering the work message.';
  final thenAt = DateTime.utc(2026, 7, 1, 10);
  final nowAt = DateTime.utc(2026, 7, 8, 10);
  final now = DateTime.utc(2026, 7, 9, 10);

  ChangeResurfacingContext contextWith({
    Set<String> live = const {'then', 'now'},
    Map<String, MemorySurfacingMode> modes = const {},
    DateTime? at,
  }) => ChangeResurfacingContext(
    liveEntryIds: live,
    surfacingModes: modes,
    now: at ?? now,
  );

  ChangeThreadView threadView({
    ChangeThreadStatus status = ChangeThreadStatus.changed,
    ChangeThreadCorrectionState correction = ChangeThreadCorrectionState.none,
    ChangeThreadVisibility visibility = ChangeThreadVisibility.visible,
    List<ChangeEvent>? events,
  }) {
    final resolved =
        events ??
        [
          _event(
            id: 'observation',
            status: ChangeThreadStatus.firstObserved,
            citations: [_citation('then', thenText, thenAt)],
            occurredAt: thenAt,
          ),
          _event(
            id: 'change',
            status: status,
            citations: [
              _citation(
                'then',
                thenText,
                thenAt,
                temporalRole: EvidenceTemporalRole.then,
              ),
              _citation(
                'now',
                nowText,
                nowAt,
                temporalRole: EvidenceTemporalRole.now,
              ),
            ],
            occurredAt: nowAt,
            dimensions: const [ChangeDimension.behaviouralResponse],
          ),
        ];
    return ChangeThreadView(
      thread: ChangeThread(
        threadId: 'work-message',
        archiveId: 'local',
        userEditableLabel: 'Answering work messages',
        subjectRepresentation: const {'work', 'message'},
        firstObservedAt: thenAt,
        latestObservedAt: resolved.last.occurredAt,
        currentStatus: status,
        evidenceEventIds: resolved.map((event) => event.eventId).toList(),
        correctionState: correction,
        visibilityState: visibility,
        policyVersion: 'change_threads_v1',
      ),
      events: resolved,
    );
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  tearDown(() => ChangeStructuredMarkers.install(null));

  group('the default list row', () {
    testWidgets('carries every fact that justifies it, and stays compact', (
      tester,
    ) async {
      final view = threadView(correction: ChangeThreadCorrectionState.renamed);
      final resurfacing = contextWith();

      await pump(
        tester,
        ChangeThreadSummaryCard(
          view: view,
          excerpt: ChangeEvidenceVisibility.safeExcerpt(
            view,
            context: resurfacing,
          ),
          resurfacing: ChangeResurfacingPolicy.noteFor(
            view,
            context: resurfacing,
          ),
          onOpen: () {},
        ),
      );

      expect(find.text('Answering work messages'), findsOneWidget);
      expect(find.text('Something changed'), findsOneWidget);
      expect(
        find.textContaining('2 saved moments · 1 July 2026 — 8 July 2026'),
        findsOneWidget,
      );
      expect(find.text('“$nowText”'), findsOneWidget);
      expect(find.text('Renamed by you'), findsOneWidget);

      // A row is a row: the quotes-and-reasoning wall stays one tap away.
      expect(find.text('Open exact moment'), findsNothing);
      expect(find.textContaining('Then ·'), findsNothing);
      expect(find.textContaining('What moved:'), findsNothing);
      for (final forbidden in ['Graph', 'Analyst', 'Blind spot', 'Life OS']) {
        expect(find.textContaining(forbidden), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('announces itself as one labelled, tappable summary', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final view = threadView();
      final resurfacing = contextWith();
      final card = ChangeThreadSummaryCard(
        view: view,
        excerpt: ChangeEvidenceVisibility.safeExcerpt(
          view,
          context: resurfacing,
        ),
        resurfacing: ChangeResurfacingPolicy.noteFor(
          view,
          context: resurfacing,
        ),
        onOpen: () {},
      );

      await pump(tester, card);

      final label = card.accessibilityLabel;
      expect(label, startsWith('Answering work messages'));
      expect(label, contains('Something changed'));
      expect(label, contains('2 saved moments'));
      expect(label, contains('1 July 2026 — 8 July 2026'));
      expect(label, contains('Strongest evidence: $nowText'));
      expect(label, contains('A new moment may change this thread.'));
      expect(
        tester.getSemantics(find.byType(ChangeThreadSummaryCard)).label,
        label,
      );
      handle.dispose();
    });

    testWidgets('drops the quote when the moment may not be shown unasked', (
      tester,
    ) async {
      final view = threadView();
      final guarded = contextWith(
        modes: const {'now': MemorySurfacingMode.sensitive},
      );

      await pump(
        tester,
        ChangeThreadSummaryCard(
          view: view,
          excerpt: ChangeEvidenceVisibility.safeExcerpt(view, context: guarded),
          resurfacing: null,
          onOpen: () {},
        ),
      );

      // The thread is still the user's; only the words stay behind a tap.
      expect(find.text('Answering work messages'), findsOneWidget);
      expect(find.text('“$nowText”'), findsNothing);
    });

    testWidgets('drops the quote when the source moment is gone', (
      tester,
    ) async {
      final view = threadView();
      final deleted = contextWith(live: const {'then'});

      await pump(
        tester,
        ChangeThreadSummaryCard(
          view: view,
          excerpt: ChangeEvidenceVisibility.safeExcerpt(view, context: deleted),
          resurfacing: null,
          onOpen: () {},
        ),
      );

      expect(find.text('“$nowText”'), findsNothing);
    });
  });

  group('evidence-based resurfacing', () {
    test('a fresh finding on an existing thread is worth mentioning', () {
      final note = ChangeResurfacingPolicy.noteFor(
        threadView(),
        context: contextWith(),
      );

      expect(note, isNotNull);
      expect(note!.reason, ChangeResurfacingReason.newMomentMayChange);
      expect(note.message, 'A new moment may change this thread.');
      expect(note.evidence, isNotEmpty);
      expect(note.sourceEntryIds, {'then', 'now'});
    });

    test('an older thread is placed in time instead', () {
      final note = ChangeResurfacingPolicy.noteFor(
        threadView(),
        context: contextWith(at: DateTime.utc(2026, 7, 22, 10)),
      );

      expect(note!.reason, ChangeResurfacingReason.firstAppeared);
      expect(note.message, 'This pattern first appeared three weeks ago.');
    });

    test('a corrected thread says so, and says nothing else', () {
      final note = ChangeResurfacingPolicy.noteFor(
        threadView(correction: ChangeThreadCorrectionState.correctedByUser),
        context: contextWith(),
      );

      expect(note!.reason, ChangeResurfacingReason.userCorrected);
      expect(note.message, 'You corrected this interpretation.');
    });

    test('stale evidence is not a reason to interrupt', () {
      final decision = ChangeResurfacingPolicy.decide(
        threadView(),
        context: contextWith(at: DateTime.utc(2027, 7, 9)),
      );

      expect(decision.isShown, isFalse);
      expect(
        decision.refusedBecause,
        ChangeResurfacingRefusal.evidenceNotRelevant,
      );
    });

    test(
      'a deleted source silences the thread rather than quoting a ghost',
      () {
        final decision = ChangeResurfacingPolicy.decide(
          threadView(),
          context: contextWith(live: const {'then'}),
        );

        expect(decision.refusedBecause, ChangeResurfacingRefusal.sourceMissing);
      },
    );

    test('a thread the user hid stays hidden', () {
      final decision = ChangeResurfacingPolicy.decide(
        threadView(
          correction: ChangeThreadCorrectionState.framingSuppressed,
          visibility: ChangeThreadVisibility.suppressed,
        ),
        context: contextWith(),
      );

      expect(decision.refusedBecause, ChangeResurfacingRefusal.hiddenByUser);
    });

    test('surfacing settings are obeyed even when everything else fits', () {
      for (final mode in [
        MemorySurfacingMode.sensitive,
        MemorySurfacingMode.doNotSurface,
      ]) {
        final decision = ChangeResurfacingPolicy.decide(
          threadView(),
          context: contextWith(modes: {'now': mode}),
        );

        expect(
          decision.refusedBecause,
          ChangeResurfacingRefusal.sensitivitySettings,
          reason: mode.id,
        );
      }
    });

    test('a thread younger than a week has nothing to resurface', () {
      final single = _event(
        id: 'observation',
        status: ChangeThreadStatus.firstObserved,
        citations: [_citation('then', thenText, thenAt)],
        occurredAt: thenAt,
      );
      final decision = ChangeResurfacingPolicy.decide(
        threadView(events: [single]),
        context: contextWith(at: thenAt.add(const Duration(days: 2))),
      );

      expect(decision.refusedBecause, ChangeResurfacingRefusal.nothingToSay);
    });
  });

  group('the thread detail', () {
    testWidgets('shows the whole chronological case for the thread', (
      tester,
    ) async {
      final view = threadView();
      await pump(
        tester,
        ChangeThreadDetailScreen(
          view: view,
          resurfacing: ChangeResurfacingPolicy.noteFor(
            view,
            context: contextWith(),
          ),
          reviewHistory: ChangeReviewHistory.forThread('work-message', [
            RenameChangeThread(
              threadId: 'work-message',
              label: 'Answering work messages',
              at: DateTime.utc(2026, 7, 10),
            ),
          ]),
        ),
      );

      expect(find.text('Answering work messages'), findsOneWidget);
      expect(find.textContaining('Something changed · 1 July 2026'), findsOne);

      // Chronological history, oldest first.
      expect(find.text('First observed'), findsOneWidget);
      expect(find.text('Something changed'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('First observed')).dy,
        lessThan(tester.getTopLeft(find.text('Something changed')).dy),
      );

      // Then/Now evidence, changed dimensions, uncertainty, source navigation.
      expect(find.textContaining('Then · 1 July 2026'), findsOneWidget);
      expect(find.textContaining('Now · 8 July 2026'), findsOneWidget);
      expect(find.textContaining('What moved: how you responded'), findsOne);
      expect(
        find.text('Later saved moments may support or challenge this read.'),
        findsNWidgets(2),
      );
      expect(find.text('Open exact moment'), findsNWidgets(3));

      // Resurfacing and review history.
      expect(find.text('A new moment may change this thread.'), findsOneWidget);
      expect(find.text('What you changed here'), findsOneWidget);
      expect(
        find.text('10 July 2026 · You renamed this thread.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without markers when no marker store is installed', (
      tester,
    ) async {
      expect(ChangeStructuredMarkers.isAvailable, isFalse);
      await pump(tester, ChangeThreadDetailScreen(view: threadView()));

      expect(find.text('Answering work messages'), findsOneWidget);
      expect(find.textContaining('Where:'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows markers once a marker store is installed', (
      tester,
    ) async {
      ChangeStructuredMarkers.install(
        (threadId) => const [
          ChangeStructuredMarker(label: 'Where', detail: 'at the office'),
        ],
      );

      await pump(tester, ChangeThreadDetailScreen(view: threadView()));

      expect(find.text('Where: at the office'), findsOneWidget);
    });

    testWidgets('survives a marker store that throws', (tester) async {
      ChangeStructuredMarkers.install(
        (threadId) => throw StateError('marker store not ready'),
      );

      await pump(tester, ChangeThreadDetailScreen(view: threadView()));

      expect(find.text('Answering work messages'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('review history', () {
    test('records both sides of a merge', () {
      final merge = MergeChangeThreads(
        threadId: 'left',
        intoThreadId: 'right',
        at: DateTime.utc(2026, 7, 11),
      );

      expect(
        ChangeReviewHistory.forThread('left', [merge]).single.description,
        'You merged this thread into another one.',
      );
      expect(
        ChangeReviewHistory.forThread('right', [merge]).single.description,
        'You merged another thread into this one.',
      );
      expect(ChangeReviewHistory.forThread('other', [merge]), isEmpty);
    });

    test('reads oldest first', () {
      final history = ChangeReviewHistory.forThread('t', [
        SuppressChangeThreadFraming(
          threadId: 't',
          eventId: 'change',
          at: DateTime.utc(2026, 7, 20),
        ),
        RenameChangeThread(
          threadId: 't',
          label: 'Renamed',
          at: DateTime.utc(2026, 7, 10),
        ),
      ]);

      expect(history.map((entry) => entry.description), [
        'You renamed this thread.',
        'You hid one reading in this thread.',
      ]);
    });
  });

  testWidgets('the empty state asks for a real moment and nothing more', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BeliefChangesScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Record a real moment. Returning gives ArchiveMe something to compare.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('changes_empty_state')), findsOneWidget);
    // No explanatory wall, and no borrowed nostalgia.
    expect(find.textContaining('On This Day'), findsNothing);
    expect(find.textContaining('Nothing to compare yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

ChangeEvent _event({
  required String id,
  required ChangeThreadStatus status,
  required List<TranscriptEvidenceCitation> citations,
  required DateTime occurredAt,
  List<ChangeDimension> dimensions = const [],
}) => ChangeEvent(
  eventId: id,
  threadId: 'work-message',
  conclusionKind: status == ChangeThreadStatus.firstObserved
      ? ExplainableInsightKind.observation
      : ExplainableInsightKind.change,
  status: status,
  changedDimensions: dimensions,
  exactEvidence: citations,
  occurredAt: occurredAt,
  confidenceBand: EvidenceConfidenceBand.someSupportingEvidence,
  uncertainty: 'Later saved moments may support or challenge this read.',
  alternativeExplanation: '',
  statement: '',
);

TranscriptEvidenceCitation _citation(
  String entryId,
  String quote,
  DateTime capturedAt, {
  EvidenceTemporalRole temporalRole = EvidenceTemporalRole.single,
}) => TranscriptEvidenceCitation(
  entryId: entryId,
  quote: quote,
  startUtf16: 0,
  endUtf16: quote.length,
  role: TranscriptEvidenceRole.supporting,
  sourceCapturedAt: capturedAt,
  sourceType: EvidenceSourceType.text,
  temporalRole: temporalRole,
  confidenceScore: 0.82,
);
