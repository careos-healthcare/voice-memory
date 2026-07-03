import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_proof_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_copy.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_gates.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_model.dart';
import 'package:voicememory_mobile/features/early_archive/what_changed_since_last_time_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/what_changed_since_last_time_copy.dart';
import 'package:voicememory_mobile/features/early_archive/what_changed_since_last_time_engine.dart';
import 'package:voicememory_mobile/features/early_archive/what_changed_since_last_time_gates.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/patterns/what_changed_since_last_time_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
    transcript: transcript,
    durationSeconds: 24,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'I said yes again',
      concreteObservation: 'Saying yes showed up again.',
      repeatedSignal: 'saying yes before ready',
    ),
  );
}

List<JournalEntry> _threeRelatedRepeatEntries() => [
      _entry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

List<JournalEntry> _fourRelatedRepeatEntries() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'I said yes again even though I had no capacity for one more ask today.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

RepeatReturnCheckRecord _choiceRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
  int entryCountAtCapture = 4,
}) =>
    RepeatReturnCheckRecord(
      entryId: entryId,
      choice: choice,
      entryCountAtCapture: entryCountAtCapture,
      createdAt: DateTime(2026, 6, 13, 12),
    );

void _expectNoDiagnosticLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
  expect(lower, isNot(contains('disorder')));
  expect(lower, isNot(contains('you always')));
  expect(lower, isNot(contains('we know you')));
  expect(lower, isNot(contains('mental health')));
}

void main() {
  setUp(() async {
    EarlyArchiveProofAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_wcslt.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  group('WhatChangedSinceLastTimeEngine', () {
    test('hidden at entryCount 3 with no return', () {
      expect(
        WhatChangedSinceLastTimeEngine.build(
          entries: _threeRelatedRepeatEntries(),
          returnChecks: const [],
        ),
        isNull,
      );
    });

    test('shown at entryCount 4+ with return check', () {
      final result = WhatChangedSinceLastTimeEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );
      expect(result, isNotNull);
      expect(result!.title, WhatChangedSinceLastTimeCopy.title);
      expect(result.state, ReturnCheckPayoffComparisonState.softer);
      expect(result.summary, WhatChangedSinceLastTimeCopy.softerSummary);
    });

    test('softer state copy', () {
      final result = WhatChangedSinceLastTimeEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );
      expect(result!.summary, WhatChangedSinceLastTimeCopy.softerSummary);
      expect(
        result.evidenceRows.last.phrase,
        WhatChangedSinceLastTimeCopy.changeSofter,
      );
    });

    test('stronger state copy', () {
      final result = WhatChangedSinceLastTimeEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.stronger),
        ],
      );
      expect(result!.summary, WhatChangedSinceLastTimeCopy.strongerSummary);
      expect(
        result.evidenceRows.last.phrase,
        WhatChangedSinceLastTimeCopy.changeStronger,
      );
    });

    test('same state copy', () {
      final result = WhatChangedSinceLastTimeEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same),
        ],
      );
      expect(result!.summary, WhatChangedSinceLastTimeCopy.sameSummary);
      expect(
        result.evidenceRows.last.phrase,
        WhatChangedSinceLastTimeCopy.changeSame,
      );
    });

    test('changed state copy', () {
      final result = WhatChangedSinceLastTimeEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.changed),
        ],
      );
      expect(result!.summary, WhatChangedSinceLastTimeCopy.changedSummary);
      expect(
        result.evidenceRows.last.phrase,
        WhatChangedSinceLastTimeCopy.changeDifferent,
      );
    });

    test('unknown fallback when comparison evidence is insufficient', () {
      final result = WhatChangedSinceLastTimeEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: const [],
      );
      expect(result, isNotNull);
      expect(result!.state, ReturnCheckPayoffComparisonState.unknown);
      expect(result.summary, WhatChangedSinceLastTimeCopy.unknownSummary);
      expect(
        result.evidenceRows.last.phrase,
        WhatChangedSinceLastTimeCopy.changeStillWatching,
      );
    });

    test('evidence rows use grounded phrases not transcript dumps', () {
      final result = WhatChangedSinceLastTimeEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      )!;
      final firstProof = result.evidenceRows.first;
      final latestReturn = result.evidenceRows[1];
      expect(firstProof.label, WhatChangedSinceLastTimeCopy.firstProofRowLabel);
      expect(latestReturn.label, WhatChangedSinceLastTimeCopy.latestReturnRowLabel);
      for (final phrase in [firstProof.phrase, latestReturn.phrase]) {
        if (phrase == null) continue;
        expect(phrase.split(RegExp(r'\s+')).length, lessThanOrEqualTo(6));
        expect(phrase.toLowerCase(), isNot(contains('even though i had no capacity')));
      }
    });
  });

  group('WhatChangedSinceLastTimeGates', () {
    test('hidden before first proof at entryCount 3', () {
      final result = WhatChangedSinceLastTimeEngine.build(
        entries: _threeRelatedRepeatEntries(),
        returnChecks: const [],
      );
      expect(
        WhatChangedSinceLastTimeGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedPostSave: false,
          viewingConfirmedRepeatOrTimeline: true,
          hasConfirmedRepeatFoundation: true,
          result: result,
        ),
        isFalse,
      );
    });

    test('hidden on post-save', () {
      final result = WhatChangedSinceLastTimeEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );
      expect(
        WhatChangedSinceLastTimeGates.shouldShow(
          loaded: true,
          entryCount: 4,
          isReady: true,
          isRecording: false,
          isPostSave: true,
          isDegradedPostSave: false,
          viewingConfirmedRepeatOrTimeline: true,
          hasConfirmedRepeatFoundation: true,
          result: result,
        ),
        isFalse,
      );
    });

    test('shown at entryCount 4+ with return check', () {
      final result = WhatChangedSinceLastTimeEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );
      expect(
        WhatChangedSinceLastTimeGates.shouldShow(
          loaded: true,
          entryCount: 4,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedPostSave: false,
          viewingConfirmedRepeatOrTimeline: true,
          hasConfirmedRepeatFoundation: true,
          result: result,
        ),
        isTrue,
      );
    });
  });

  group('WhatChangedSinceLastTimeCopy guard', () {
    test('avoids advice coaching and personality language', () {
      final joined = [
        WhatChangedSinceLastTimeCopy.title,
        WhatChangedSinceLastTimeCopy.softerSummary,
        WhatChangedSinceLastTimeCopy.strongerSummary,
        WhatChangedSinceLastTimeCopy.sameSummary,
        WhatChangedSinceLastTimeCopy.changedSummary,
        WhatChangedSinceLastTimeCopy.unknownSummary,
        WhatChangedSinceLastTimeCopy.footer,
      ].join(' ').toLowerCase();

      expect(joined, isNot(contains('you should')));
      expect(joined, isNot(contains('try this')));
      expect(joined, isNot(contains('this means')));
      expect(joined, isNot(contains('you are')));
      for (final line in [
        WhatChangedSinceLastTimeCopy.title,
        WhatChangedSinceLastTimeCopy.footer,
        WhatChangedSinceLastTimeCopy.softerSummary,
      ]) {
        _expectNoDiagnosticLanguage(line);
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('does not duplicate ReturnCheckPayoff titles on Patterns surface', () {
      expect(
        WhatChangedSinceLastTimeCopy.softerSummary,
        isNot(ReturnCheckPayoffCopy.softerTitle),
      );
      expect(
        WhatChangedSinceLastTimeCopy.strongerSummary,
        isNot(ReturnCheckPayoffCopy.strongerTitle),
      );
      expect(
        WhatChangedSinceLastTimeCopy.changedSummary,
        isNot(ReturnCheckPayoffCopy.changedTitle),
      );
      expect(
        WhatChangedSinceLastTimeCopy.title,
        isNot(ReturnCheckPayoffCopy.evidenceLabel),
      );
      expect(
        WhatChangedSinceLastTimeCopy.footer,
        isNot(contains(ReturnCheckPayoffCopy.softerFooter)),
      );
    });
  });

  group('WhatChangedSinceLastTimeCard', () {
    testWidgets('renders title summary evidence rows and footer', (tester) async {
      final result = WhatChangedSinceLastTimeEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatChangedSinceLastTimeCard(
              result: result,
              entryCount: 4,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('what_changed_since_last_time_card')), findsOneWidget);
      expect(find.text(WhatChangedSinceLastTimeCopy.title), findsOneWidget);
      expect(find.text(WhatChangedSinceLastTimeCopy.softerSummary), findsOneWidget);
      expect(find.text(WhatChangedSinceLastTimeCopy.evidenceLabel), findsOneWidget);
      expect(find.text(WhatChangedSinceLastTimeCopy.footer), findsOneWidget);
      expect(
        find.byKey(
          const Key('proof_surface_why_appeared_link_what_changed_since_last_time'),
        ),
        findsOneWidget,
      );
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsOneWidget);
    });
  });

  group('WhatChangedSinceLastTimeAnalytics', () {
    late List<({String event, Map<String, Object> properties})> captured;

    setUp(() {
      captured = [];
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) => captured.add((event: event, properties: properties)),
      );
    });

    tearDown(ActivationFunnelAnalytics.resetForTest);

    test('metadata only without transcript or phrase text', () {
      WhatChangedSinceLastTimeAnalytics.seen(
        entryCount: 4,
        comparisonState: ReturnCheckPayoffComparisonState.softer,
        hasPhrase: true,
        hasConfirmedRepeat: true,
      );

      expect(captured, hasLength(1));
      expect(
        captured.single.event,
        EarlyArchiveProofAnalytics.whatChangedSinceLastTimeSeenEvent,
      );
      final payload = captured.single.properties;
      expect(payload['entry_count'], 4);
      expect(payload['source'], 'patterns');
      expect(payload['comparison_state'], 'softer');
      expect(payload['has_phrase'], 1);
      expect(payload['has_confirmed_repeat'], 1);
      expect(payload.values.whereType<String>(), isNot(contains('said yes again')));
    });
  });

  group('Record post-save isolation', () {
    test('ReturnCheckPayoff remains post-save only', () {
      final payoff = WhatChangedSinceLastTimeEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );
      expect(payoff, isNotNull);
      expect(
        ReturnCheckPayoffGates.shouldShow(
          isPostSaveDone: false,
          entryCount: 4,
          isDegradedPostSave: false,
          showFirstProofMoment: false,
          showPostSaveReturnCheckAnswer: false,
          payoff: null,
        ),
        isFalse,
      );
    });
  });

  group('Billing isolation', () {
    test('billing RevenueCat restore untouched', () {
      final cardSource = File(
        'lib/widgets/patterns/what_changed_since_last_time_card.dart',
      ).readAsStringSync();
      expect(cardSource.toLowerCase(), isNot(contains('revenuecat')));
      expect(cardSource.toLowerCase(), isNot(contains('restorepurchase')));
      expect(cardSource.toLowerCase(), isNot(contains('billing')));
    });
  });

  group('Patterns screen isolation', () {
    test('archive belief screen does not import ReturnCheckPayoffCard', () {
      final source = File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      expect(source.contains('ReturnCheckPayoffCard'), isFalse);
      expect(source.contains('what_changed_since_last_time_card'), isTrue);
    });
  });
}
