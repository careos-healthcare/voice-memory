import 'dart:io';
import 'support/record_screen_library_source.dart';

import 'package:archiveme_mobile/features/timeline_positioning/timeline_positioning_analytics.dart';
import 'package:archiveme_mobile/features/timeline_positioning/timeline_positioning_copy.dart';
import 'package:archiveme_mobile/features/timeline_positioning/timeline_positioning_engine.dart';
import 'package:archiveme_mobile/features/timeline_positioning/timeline_positioning_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/patterns/timeline_positioning_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry(String id, String transcript) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 24,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  ),
);

TimelinePositioningResult _resultFor(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = false,
}) => TimelinePositioningEngine.build(
  entries: entries,
  beliefSurfaceVisible: beliefSurfaceVisible,
  source: 'test',
);

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() {
    TimelinePositioningAnalytics.resetForTest();
    TimelinePositioningAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
  });

  tearDown(TimelinePositioningAnalytics.resetForTest);

  group('TimelinePositioningEngine', () {
    test('hidden during degraded transcript', () {
      final result = _resultFor([_entry('1', _strongRepeat)]);
      expect(
        TimelinePositioningEngine.shouldShowOnRecordReady(
          result: result,
          entryCount: 0,
          otherEducationCardCount: 0,
          isDegradedTranscriptState: true,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during first proof payoff', () {
      final result = _resultFor([_entry('1', _strongRepeat)]);
      expect(
        TimelinePositioningEngine.shouldShow(
          result: result,
          otherEducationCardCount: 0,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: true,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during active What Changed', () {
      final result = _resultFor([_entry('1', _strongRepeat)]);
      expect(
        TimelinePositioningEngine.shouldShow(
          result: result,
          otherEducationCardCount: 0,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden when stacked with more than one other education card', () {
      final result = _resultFor([_entry('1', _strongRepeat)]);
      expect(
        TimelinePositioningEngine.shouldShowOnRecordReady(
          result: result,
          entryCount: 3,
          otherEducationCardCount: 2,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test(
      'shows for early record user with at most one other education card',
      () {
        final result = _resultFor([_entry('1', _strongRepeat)]);
        expect(
          TimelinePositioningEngine.shouldShowOnRecordReady(
            result: result,
            entryCount: 2,
            otherEducationCardCount: 1,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: false,
            firstProofPayoffVisible: false,
            whatChangedQuestionActive: false,
            patternReviewInboxHasActiveItems: false,
          ),
          isTrue,
        );
      },
    );
  });

  group('TimelinePositioningCard', () {
    Future<void> pumpCard(
      WidgetTester tester,
      TimelinePositioningResult result, {
      bool compact = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelinePositioningCard.test(
              result: result,
              source: 'test',
              compact: compact,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders "Not a chat. A timeline."', (tester) async {
      await pumpCard(tester, _resultFor([_entry('1', _strongRepeat)]));

      expect(
        find.byKey(const Key('timeline_positioning_card')),
        findsOneWidget,
      );
      expect(find.text(TimelinePositioningCopy.title), findsOneWidget);
    });

    testWidgets('renders ChatGPT differentiation line', (tester) async {
      await pumpCard(tester, _resultFor([_entry('1', _strongRepeat)]));

      expect(
        find.byKey(const Key('timeline_positioning_differentiation_line')),
        findsOneWidget,
      );
      expect(
        find.text(TimelinePositioningCopy.differentiationLine),
        findsOneWidget,
      );
    });

    testWidgets('renders timeline bullets', (tester) async {
      await pumpCard(tester, _resultFor([_entry('1', _strongRepeat)]));

      for (final bullet in TimelinePositioningCopy.timelineBullets) {
        expect(
          find.byKey(Key(TimelinePositioningCopy.bulletKey(bullet))),
          findsOneWidget,
        );
      }
    });

    testWidgets('does not expose transcript/body/private text', (tester) async {
      await pumpCard(tester, _resultFor([_entry('1', _strongRepeat)]));

      expect(find.textContaining(_strongRepeat), findsNothing);
      expect(find.textContaining('localAudioPath'), findsNothing);
      expect(find.textContaining('transcript'), findsNothing);
    });

    testWidgets('does not include subscription CTA', (tester) async {
      await pumpCard(tester, _resultFor([_entry('1', _strongRepeat)]));

      expect(find.textContaining('Subscribe'), findsNothing);
      expect(find.byKey(const Key('pro_evidence_value_cta')), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('metadata-only analytics', (tester) async {
      await pumpCard(tester, _resultFor([_entry('1', _strongRepeat)]));

      expect(analyticsEvents, hasLength(1));
      final record = analyticsEvents.single;
      expect(record.event, 'timeline_positioning_seen');
      expect(
        record.props.keys,
        containsAll([
          'source',
          'entry_count',
          'has_confirmed_repeat',
          'has_belief_surface',
        ]),
      );
      for (final value in record.props.values) {
        final text = value.toString().toLowerCase();
        expect(text, isNot(contains('transcript')));
        expect(text, isNot(contains(_strongRepeat.toLowerCase())));
      }
    });
  });

  group('Timeline positioning placement', () {
    test('record screen renders card before Pro evidence bridge', () {
      final source = readRecordScreenLibrarySource();
      final cardIndex = source.indexOf('ctx.showTimelinePositioningOnRecordReady');
      final proBridgeIndex = source.indexOf(
        'showProEvidenceValueOnRecordReady',
      );
      expect(cardIndex, greaterThan(0));
      expect(proBridgeIndex, greaterThan(cardIndex));
    });

    test('record card sits above current relevance card', () {
      final source = readRecordScreenLibrarySource();
      final timelineIndex = source.indexOf('TimelinePositioningCard(');
      final relevanceIndex = source.indexOf('CurrentRelevanceCard(');
      expect(timelineIndex, greaterThan(0));
      expect(relevanceIndex, greaterThan(timelineIndex));
    });

    test('record card sits after capture freedom line', () {
      final source = readRecordScreenLibrarySource();
      final freedomIndex = source.indexOf(
        'if (ctx.showCaptureFreedomLine &&\n'
        '            !ctx.firstUseSimplifiedRecord &&\n'
        '            !ctx.showReturningWatchTargetFocusedUi) ...[',
      );
      final timelineIndex = source.indexOf(
        'ctx.showTimelinePositioningOnRecordReady',
      );
      expect(freedomIndex, greaterThan(0));
      expect(timelineIndex, greaterThan(freedomIndex));
    });
  });

  group('TimelinePositioning copy guard', () {
    test('no therapy/diagnosis/treatment claims', () {
      final blob = TimelinePositioningCopy.all.join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
    });

    test('no "better than ChatGPT" claim', () {
      final blob = TimelinePositioningCopy.all.join(' ').toLowerCase();
      expect(blob, isNot(contains('better than chatgpt')));
      expect(blob, isNot(contains('better than claude')));
      expect(blob, isNot(contains('better than gemini')));
    });

    test('no "more AI" positioning as product value', () {
      final blob = TimelinePositioningCopy.all.join(' ').toLowerCase();
      expect(blob, isNot(contains('more ai answers')));
      expect(blob, isNot(contains('more ai conversation for')));
      expect(blob, contains('not more ai conversation'));
    });
  });
}