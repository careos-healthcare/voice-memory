import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/early_archive/helpful_action_appeared_analytics.dart';
import 'package:archiveme_mobile/features/early_archive/helpful_action_appeared_copy.dart';
import 'package:archiveme_mobile/features/early_archive/helpful_action_appeared_engine.dart';
import 'package:archiveme_mobile/features/early_archive/helpful_action_appeared_gates.dart';
import 'package:archiveme_mobile/features/early_archive/positive_reinforcement_copy.dart';
import 'package:archiveme_mobile/features/early_archive/record_proof_stack_policy.dart';
import 'package:archiveme_mobile/features/repeat_return_check/pattern_changed_copy.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/patterns/helpful_action_appeared_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      exactLanguagePattern: '',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: '',
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

List<JournalEntry> _fourRelatedRepeatWithHelpfulAction() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript: 'I paused before replying this time and it felt a bit softer.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

List<JournalEntry> _threeGenericFeelingEntries() => [
  _entry(
    id: 'g1',
    transcript: 'I felt grateful and happy today about everything.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'g2',
    transcript: 'Another good day — feeling good and positive.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'g3',
    transcript: 'Still feeling better and grateful this week.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
  _entry(
    id: 'g4',
    transcript: 'Grateful again today with no concrete action.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

RepeatReturnCheckRecord _choiceRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
}) => RepeatReturnCheckRecord(
  entryId: entryId,
  choice: choice,
  entryCountAtCapture: 4,
  createdAt: DateTime(2026, 6, 13, 12),
);

void _expectNoAdviceLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('you should')));
  expect(lower, isNot(contains('try this')));
  expect(lower, isNot(contains('do this again')));
  expect(lower, isNot(contains('therapy')));
  expect(lower, isNot(contains('diagnosis')));
}

void main() {
  setUp(() async {
    HelpfulActionAppearedAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_haa.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  group('HelpfulActionAppearedEngine', () {
    test('helpful action from user words appears', () {
      final result = HelpfulActionAppearedEngine.build(
        entries: _fourRelatedRepeatWithHelpfulAction(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );
      expect(result, isNotNull);
      expect(result!.title, HelpfulActionAppearedCopy.title);
      expect(result.usesActionPhrase, isTrue);
      expect(result.actionPhrase, isNotNull);
      expect(result.body.toLowerCase(), contains('paused before replying'));
    });

    test('concrete action phrase max 6 words', () {
      final result = HelpfulActionAppearedEngine.build(
        entries: _fourRelatedRepeatWithHelpfulAction(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );
      final words = result!.actionPhrase!.trim().split(RegExp(r'\s+'));
      expect(words.length, lessThanOrEqualTo(6));
    });

    test('generic feelings alone do not show card', () {
      expect(
        HelpfulActionAppearedEngine.build(
          entries: _threeGenericFeelingEntries(),
          returnChecks: const [],
        ),
        isNull,
      );
    });

    test('hidden before first proof at entry 3', () {
      expect(
        HelpfulActionAppearedEngine.build(
          entries: _threeRelatedRepeatEntries(),
          returnChecks: const [],
        ),
        isNull,
      );
    });

    test('fallback when improvement signal without grounded phrase', () {
      final result = HelpfulActionAppearedEngine.build(
        entries: [
          ..._threeRelatedRepeatEntries(),
          _entry(
            id: 'e4',
            transcript:
                'I said yes again even though I had no capacity — softer this time.',
          ),
        ],
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );
      expect(result, isNotNull);
      expect(result!.usesActionPhrase, isFalse);
      expect(result.body, HelpfulActionAppearedCopy.bodyFallback);
    });

    test('weak ungrounded action does not overclaim with phrase', () {
      final entries = [
        ..._threeRelatedRepeatEntries(),
        _entry(
          id: 'e4',
          transcript:
              'I felt more confidence and growth today after the repeat.',
        ),
      ];
      final result = HelpfulActionAppearedEngine.build(
        entries: entries,
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.changed),
        ],
      );
      if (result != null) {
        expect(result.usesActionPhrase, isFalse);
      }
    });
  });

  group('HelpfulActionAppearedCopy', () {
    test('copy says Evidence, not advice', () {
      expect(HelpfulActionAppearedCopy.evidenceLabel, 'Evidence, not advice');
    });

    test('copy says this is not a suggestion', () {
      expect(
        HelpfulActionAppearedCopy.footer.toLowerCase(),
        contains('this is not a suggestion'),
      );
    });

    test('no advice coaching language', () {
      [
        HelpfulActionAppearedCopy.title,
        HelpfulActionAppearedCopy.bodyFallback,
        HelpfulActionAppearedCopy.footer,
        HelpfulActionAppearedCopy.bodyWithPhrase('walked outside'),
      ].forEach(_expectNoAdviceLanguage);
    });

    test('passes proof surface advice guard', () {
      for (final copy in ProofSurfaceAdviceGuard.mainProofSurfaceCopyBlocks()) {
        expect(ProofSurfaceAdviceGuard.passes(copy), isTrue, reason: copy);
      }
    });
  });

  group('HelpfulActionAppearedGates', () {
    test('hidden during entry 1–2', () {
      final result = HelpfulActionAppearedEngine.build(
        entries: _fourRelatedRepeatWithHelpfulAction(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );
      expect(
        HelpfulActionAppearedGates.shouldShow(
          loaded: true,
          entryCount: 2,
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

    test('hidden while recording', () {
      final result = HelpfulActionAppearedEngine.build(
        entries: _fourRelatedRepeatWithHelpfulAction(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );
      expect(
        HelpfulActionAppearedGates.shouldShow(
          loaded: true,
          entryCount: 4,
          isReady: true,
          isRecording: true,
          isPostSave: false,
          isDegradedPostSave: false,
          viewingConfirmedRepeatOrTimeline: true,
          hasConfirmedRepeatFoundation: true,
          result: result,
        ),
        isFalse,
      );
    });
  });

  group('HelpfulActionAppearedCard', () {
    testWidgets('renders title body evidence label and footer', (tester) async {
      final result = HelpfulActionAppearedEngine.build(
        entries: _fourRelatedRepeatWithHelpfulAction(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HelpfulActionAppearedCard(
              result: result,
              entryCount: 4,
              source: 'patterns',
            ),
          ),
        ),
      );

      expect(find.text(HelpfulActionAppearedCopy.title), findsOneWidget);
      expect(
        find.text(HelpfulActionAppearedCopy.evidenceLabel),
        findsOneWidget,
      );
      expect(find.text(HelpfulActionAppearedCopy.footer), findsOneWidget);
      expect(find.text(HelpfulActionAppearedCopy.chipLabel), findsOneWidget);
      expect(
        find.byKey(const Key('helpful_action_appeared_card')),
        findsOneWidget,
      );
    });
  });

  group('HelpfulActionAppearedAnalytics', () {
    test('metadata only without transcript or phrase text', () {
      Map<String, Object>? captured;
      HelpfulActionAppearedAnalytics.captureForTest = (event, props) {
        captured = props;
      };

      HelpfulActionAppearedAnalytics.seen(
        entryCount: 4,
        source: 'patterns',
        hasActionPhrase: true,
        hasConfirmedRepeat: true,
      );

      expect(captured, isNotNull);
      expect(
        captured!.keys,
        containsAll([
          'entry_count',
          'source',
          'has_action_phrase',
          'has_confirmed_repeat',
        ]),
      );
      expect(captured!.keys, isNot(contains('transcript')));
      expect(captured!.keys, isNot(contains('phrase')));
      expect(captured!['has_action_phrase'], 1);
    });
  });

  group('Dedup and placement', () {
    test('title distinct from positive reinforcement', () {
      expect(
        HelpfulActionAppearedCopy.title,
        isNot(PositiveReinforcementCopy.title),
      );
      expect(HelpfulActionAppearedCopy.title, isNot(PatternChangedCopy.title));
    });

    test('record proof stack cap respected when helpful action shown', () {
      final decision = RecordProofStackPolicy.decide(
        loaded: true,
        entryCount: 5,
        isReady: true,
        isPostSave: false,
        isRecording: false,
        archiveSummaryVisible: false,
        hasEarlyFirstSignal: true,
        hasEarlyEvidenceTimeline: false,
        patternChangedVisible: false,
        dailyReturnReasonEligible: false,
        weeklyReviewEligible: false,
        privateReportEligible: false,
        whyMattersEligible: false,
        thoughtMapEligible: false,
        positiveReinforcementEligible: true,
        helpfulActionAppearedEligible: true,
        changeProofEligible: false,
        firstWeekLoopEligible: true,
        proBridgeEligible: true,
      );

      expect(decision.showHelpfulActionAppeared, isTrue);
      expect(decision.showPositiveReinforcement, isFalse);
      expect(decision.proofCardCount, lessThanOrEqualTo(3));
    });
  });
}