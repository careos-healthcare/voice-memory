import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_proof_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_copy.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_engine.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_gates.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_model.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/record/return_check_payoff_card.dart';

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
}) => RepeatReturnCheckRecord(
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
    ActivationFunnelAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_rcp.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  group('ReturnCheckPayoffEngine', () {
    test('hidden at entryCount 0–3', () {
      for (final count in [1, 2, 3]) {
        expect(
          ReturnCheckPayoffEngine.build(
            entries: _threeRelatedRepeatEntries().take(count).toList(),
            returnChecks: const [],
          ),
          isNull,
        );
      }
    });

    test('shown after fourth related post-save', () {
      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: const [],
      );
      expect(payoff, isNotNull);
      expect(payoff!.state, ReturnCheckPayoffComparisonState.unknown);
      expect(payoff.title, ReturnCheckPayoffCopy.unknownTitle);
    });

    test('hidden for unrelated fourth entry', () {
      expect(
        ReturnCheckPayoffEngine.build(
          entries: [
            ..._threeRelatedRepeatEntries(),
            _entry(
              id: 'e4',
              transcript:
                  'Weather was nice on my walk through the park and felt calmer outside.',
            ),
          ],
          returnChecks: const [],
        ),
        isNull,
      );
    });

    test('softer copy when latest return check is softer', () {
      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );
      expect(payoff!.state, ReturnCheckPayoffComparisonState.softer);
      expect(payoff.title, ReturnCheckPayoffCopy.softerTitle);
      expect(payoff.evidenceLabel, contains('first proof'));
      expect(payoff.body, contains('said yes'));
      expect(payoff.footer, contains('keep watching'));
    });

    test('stronger copy when latest return check is stronger', () {
      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.stronger,
          ),
        ],
      );
      expect(payoff!.state, ReturnCheckPayoffComparisonState.stronger);
      expect(payoff.title, ReturnCheckPayoffCopy.strongerTitle);
    });

    test('same copy when latest return check is same', () {
      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same),
        ],
      );
      expect(payoff!.state, ReturnCheckPayoffComparisonState.same);
      expect(payoff.title, ReturnCheckPayoffCopy.sameTitle);
    });

    test('same copy when softer then same without changed choice', () {
      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e3', choice: RepeatReturnCheckChoice.softer),
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same),
        ],
      );
      expect(payoff!.state, ReturnCheckPayoffComparisonState.same);
      expect(payoff.title, ReturnCheckPayoffCopy.sameTitle);
    });

    test('unknown fallback when latest entry has no return check choice', () {
      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: const [],
      );
      expect(payoff!.state, ReturnCheckPayoffComparisonState.unknown);
      expect(payoff.body, ReturnCheckPayoffCopy.unknownBody);
      expect(payoff.footer, ReturnCheckPayoffCopy.unknownFooter);
    });

    test('fallback body when phrase unavailable', () {
      final entries = _fourRelatedRepeatEntries();
      final payoff = ReturnCheckPayoffEngine.build(
        entries: entries,
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );
      expect(payoff, isNotNull);
      if (!payoff!.usesPhraseBody) {
        expect(payoff.body, ReturnCheckPayoffCopy.softerBodyFallback);
      } else {
        expect(payoff.body, contains('said yes'));
      }
    });
  });

  group('ReturnCheckPayoffGates', () {
    test('hidden on ready state and degraded post-save', () {
      const payoff = ReturnCheckPayoff(
        state: ReturnCheckPayoffComparisonState.unknown,
        title: ReturnCheckPayoffCopy.unknownTitle,
        body: ReturnCheckPayoffCopy.unknownBody,
        evidenceLabel: ReturnCheckPayoffCopy.evidenceLabel,
        footer: ReturnCheckPayoffCopy.unknownFooter,
        hasPhrase: false,
        hasConfirmedRepeat: true,
        usesPhraseBody: false,
      );

      expect(
        ReturnCheckPayoffGates.shouldShow(
          isPostSaveDone: false,
          entryCount: 4,
          isDegradedPostSave: false,
          showFirstProofMoment: false,
          showPostSaveReturnCheckAnswer: false,
          payoff: payoff,
        ),
        isFalse,
      );
      expect(
        ReturnCheckPayoffGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 4,
          isDegradedPostSave: true,
          showFirstProofMoment: false,
          showPostSaveReturnCheckAnswer: false,
          payoff: payoff,
        ),
        isFalse,
      );
    });

    test('hidden when first proof moment is showing', () {
      const payoff = ReturnCheckPayoff(
        state: ReturnCheckPayoffComparisonState.unknown,
        title: ReturnCheckPayoffCopy.unknownTitle,
        body: ReturnCheckPayoffCopy.unknownBody,
        evidenceLabel: ReturnCheckPayoffCopy.evidenceLabel,
        footer: ReturnCheckPayoffCopy.unknownFooter,
        hasPhrase: false,
        hasConfirmedRepeat: true,
        usesPhraseBody: false,
      );

      expect(
        ReturnCheckPayoffGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 4,
          isDegradedPostSave: false,
          showFirstProofMoment: true,
          showPostSaveReturnCheckAnswer: false,
          payoff: payoff,
        ),
        isFalse,
      );
    });

    test('hidden when answer question is visible and payoff is unknown', () {
      const payoff = ReturnCheckPayoff(
        state: ReturnCheckPayoffComparisonState.unknown,
        title: ReturnCheckPayoffCopy.unknownTitle,
        body: ReturnCheckPayoffCopy.unknownBody,
        evidenceLabel: ReturnCheckPayoffCopy.evidenceLabel,
        footer: ReturnCheckPayoffCopy.unknownFooter,
        hasPhrase: false,
        hasConfirmedRepeat: true,
        usesPhraseBody: false,
      );

      expect(
        ReturnCheckPayoffGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 4,
          isDegradedPostSave: false,
          showFirstProofMoment: false,
          showPostSaveReturnCheckAnswer: true,
          payoff: payoff,
        ),
        isFalse,
      );
    });
  });

  group('ReturnCheckPayoffCard', () {
    testWidgets('renders without extra primary CTA', (tester) async {
      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnCheckPayoffCard(payoff: payoff, entryCount: 4),
          ),
        ),
      );

      expect(
        find.byKey(const Key('return_check_payoff_card_softer')),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });

  group('ReturnCheckPayoffAnalytics', () {
    late List<({String event, Map<String, Object> properties})> captured;

    setUp(() {
      captured = [];
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );
    });

    tearDown(ActivationFunnelAnalytics.resetForTest);

    test('metadata omits transcript and phrase text', () {
      ReturnCheckPayoffAnalytics.seen(
        entryCount: 4,
        comparisonState: ReturnCheckPayoffComparisonState.softer,
        hasPhrase: true,
        hasConfirmedRepeat: true,
      );

      expect(captured, hasLength(1));
      final payload = captured.single.properties;
      expect(
        captured.single.event,
        EarlyArchiveProofAnalytics.returnCheckPayoffSeenEvent,
      );
      expect(payload['entry_count'], 4);
      expect(payload['source'], 'record');
      expect(payload['comparison_state'], 'softer');
      expect(payload['has_phrase'], 1);
      expect(payload['has_confirmed_repeat'], 1);
      expect(
        payload.values.whereType<String>(),
        isNot(contains('said yes again')),
      );
    });
  });

  group('ReturnCheckPayoffCopy guard', () {
    test('copy compares with first proof and tracks change over time', () {
      final joined = [
        ReturnCheckPayoffCopy.evidenceLabel,
        ReturnCheckPayoffCopy.softerTitle,
        ReturnCheckPayoffCopy.strongerTitle,
        ReturnCheckPayoffCopy.sameTitle,
        ReturnCheckPayoffCopy.changedTitle,
        ReturnCheckPayoffCopy.unknownBody,
        ReturnCheckPayoffCopy.softerFooter,
      ].join(' ').toLowerCase();

      expect(joined, contains('first proof'));
      expect(joined, contains('stronger'));
      expect(joined, contains('softer'));
      expect(joined, contains('about the same'));
      expect(joined, contains('what changed'));
    });

    test(
      'post-save payoff avoids repeating intensity labels in body and footer',
      () {
        final payoff = ReturnCheckPayoffEngine.build(
          entries: _fourRelatedRepeatEntries(),
          returnChecks: [
            _choiceRecord(
              entryId: 'e4',
              choice: RepeatReturnCheckChoice.softer,
            ),
          ],
        )!;
        final combined = '${payoff.title}\n${payoff.body}\n${payoff.footer}'
            .toLowerCase();
        expect(
          ArchiveProofCopyDedup.countPhrase(combined, 'softer'),
          lessThanOrEqualTo(2),
        );
        expect(combined, isNot(contains('you should')));
        expect(combined, isNot(contains('try to')));
      },
    );

    test('payoff copy uses evidence comparison language', () {
      final joined = [
        ReturnCheckPayoffCopy.evidenceLabel,
        ReturnCheckPayoffCopy.softerBodyFallback,
        ReturnCheckPayoffCopy.strongerBodyFallback,
        ReturnCheckPayoffCopy.changedBodyFallback,
        ReturnCheckPayoffCopy.softerFooter,
        ReturnCheckPayoffCopy.unknownFooter,
      ].join(' ').toLowerCase();

      expect(joined, contains('first proof'));
      expect(joined, contains('evidence'));
      expect(joined, contains('connects'));
      expect(joined, contains('watching'));
    });

    test('copy avoids therapy diagnosis and personality claims', () {
      const copy = [
        ReturnCheckPayoffCopy.softerTitle,
        ReturnCheckPayoffCopy.softerBodyFallback,
        ReturnCheckPayoffCopy.strongerTitle,
        ReturnCheckPayoffCopy.strongerBodyFallback,
        ReturnCheckPayoffCopy.sameTitle,
        ReturnCheckPayoffCopy.sameBodyFallback,
        ReturnCheckPayoffCopy.changedTitle,
        ReturnCheckPayoffCopy.changedBodyFallback,
        ReturnCheckPayoffCopy.unknownTitle,
        ReturnCheckPayoffCopy.unknownBody,
        ReturnCheckPayoffCopy.evidenceLabel,
      ];
      for (final line in copy) {
        _expectNoDiagnosticLanguage(line);
      }
    });
  });

  group('Patterns screen isolation', () {
    test('archive belief screen does not import return check payoff card', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      expect(source.contains('return_check_payoff'), isFalse);
      expect(source.contains('ReturnCheckPayoffCard'), isFalse);
    });
  });
}
