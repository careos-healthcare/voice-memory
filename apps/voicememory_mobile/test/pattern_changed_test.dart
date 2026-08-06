import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/early_archive/record_proof_stack_policy.dart';
import 'package:voicememory_mobile/features/early_archive/what_changed_since_last_time_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_analytics.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_gates.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_store.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/pattern_changed_card.dart';

RepeatReturnCheckRecord _answeredRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
  int entryCountAtCapture = 4,
}) {
  return RepeatReturnCheckRecord(
    entryId: entryId,
    choice: choice,
    entryCountAtCapture: entryCountAtCapture,
    createdAt: DateTime(2026, 6, 13),
  );
}

RepeatReturnCheckChangeProof _proofForChoice(RepeatReturnCheckChoice choice) {
  return RepeatReturnCheckChangeProof(
    title: RepeatReturnCheckCopy.changeProofTitle,
    body: RepeatReturnCheckTrendEngine.bodyForChoice(choice),
    latestChoice: choice,
  );
}

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

List<JournalEntry> _fourRelatedRepeatEntries() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'I said yes again even though I had no capacity for one more ask today.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

List<JournalEntry> _fourWithDifferentLatestPhrase() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'I walked outside for five minutes before I replied to the message.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/pattern_changed/unused.json'));

  final Map<String, Map<String, dynamic>> jsonMaps = {};

  @override
  Future<Map<String, dynamic>?> readJsonMap(String key) async => jsonMaps[key];

  @override
  Future<void> writeJsonMap(String key, Map<String, dynamic> value) async {
    jsonMaps[key] = value;
  }
}

void _expectNoDiagnosticLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
  expect(lower, isNot(contains('disorder')));
}

void _expectNoAdviceLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('you should')));
  expect(lower, isNot(contains('try this')));
  expect(lower, isNot(contains('this means')));
  expect(lower, isNot(contains('you are')));
  expect(lower, isNot(contains('you always')));
}

void _expectPhraseWithinSixWords(String? phrase) {
  expect(phrase, isNotNull);
  final words = phrase!.trim().split(RegExp(r'\s+'));
  expect(words.length, lessThanOrEqualTo(6));
}

void main() {
  setUp(() async {
    PatternChangedAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath:
          '${DateTime.now().microsecondsSinceEpoch}_pattern_changed.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await PatternChangedStore.resetForTest();
  });

  group('PatternChangedEngine', () {
    test('hidden before change proof', () {
      expect(
        PatternChangedEngine.build(
          changeProof: null,
          records: const [],
          entries: const [],
        ),
        isNull,
      );
      expect(
        PatternChangedEngine.build(
          changeProof: _proofForChoice(RepeatReturnCheckChoice.softer),
          records: const [],
          entries: _fourRelatedRepeatEntries(),
        ),
        isNull,
      );
    });

    test('does not trigger for stronger only', () {
      final proof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 4,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.stronger,
          ),
        ],
      );
      expect(
        PatternChangedEngine.build(
          changeProof: proof,
          records: [
            _answeredRecord(
              entryId: 'e4',
              choice: RepeatReturnCheckChoice.stronger,
            ),
          ],
          entries: _fourRelatedRepeatEntries(),
        ),
        isNull,
      );
    });

    test(
      'does not trigger for softer only without meaningful phrase evidence',
      () {
        final proof = RepeatReturnCheckEngine.changeProofForReady(
          entryCount: 4,
          viewingConfirmedRepeat: true,
          isRecording: false,
          isPostSave: false,
          records: [
            _answeredRecord(
              entryId: 'e4',
              choice: RepeatReturnCheckChoice.softer,
            ),
          ],
        );
        expect(
          PatternChangedEngine.build(
            changeProof: proof,
            records: [
              _answeredRecord(
                entryId: 'e4',
                choice: RepeatReturnCheckChoice.softer,
              ),
            ],
            entries: _fourRelatedRepeatEntries(),
          ),
          isNull,
        );
      },
    );

    test('shows softer when phrase evidence meaningfully differs', () {
      final entries = _fourWithDifferentLatestPhrase();
      final proof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 4,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
      );
      final result = PatternChangedEngine.build(
        changeProof: proof,
        records: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
        entries: entries,
      );
      expect(result, isNotNull);
      expect(result!.title, PatternChangedCopy.title);
      expect(result.usesPhraseEvidence, isTrue);
      expect(result.earlierPhrase, isNotNull);
      expect(result.thisTimePhrase, isNotNull);
      expect(
        result.earlierPhrase!.toLowerCase(),
        isNot(equals(result.thisTimePhrase!.toLowerCase())),
      );
      _expectPhraseWithinSixWords(result.earlierPhrase);
      _expectPhraseWithinSixWords(result.thisTimePhrase);
    });

    test('meaningful changed state shows unified title and footer', () {
      final proof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 4,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
      );
      final result = PatternChangedEngine.build(
        changeProof: proof,
        records: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        entries: _fourRelatedRepeatEntries(),
      );
      expect(result, isNotNull);
      expect(result!.type, PatternChangedType.changed);
      expect(result.title, 'Something changed this time');
      expect(result.footer, PatternChangedCopy.footer);
      expect(result.isCelebration, isTrue);
    });

    test('changed choice uses fallback when phrase evidence is weak', () {
      final proof = _proofForChoice(RepeatReturnCheckChoice.changed);
      final result = PatternChangedEngine.build(
        changeProof: proof,
        records: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        entries: _fourRelatedRepeatEntries(),
      );
      expect(result, isNotNull);
      expect(result!.usesPhraseEvidence, isFalse);
      expect(result.body, PatternChangedCopy.bodyFallback);
    });

    test('hidden on steady same-only answer', () {
      final proof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 4,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: [
          _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same),
        ],
      );
      expect(
        PatternChangedEngine.build(
          changeProof: proof,
          records: [
            _answeredRecord(
              entryId: 'e4',
              choice: RepeatReturnCheckChoice.same,
            ),
          ],
          entries: _fourRelatedRepeatEntries(),
        ),
        isNull,
      );
    });

    test('does not trigger for softer then same without changed choice', () {
      final records = [
        _answeredRecord(entryId: 'e5', choice: RepeatReturnCheckChoice.same),
        _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
      ];
      final proof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 5,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: records,
      );
      expect(
        PatternChangedEngine.build(
          changeProof: proof,
          records: records,
          entries: _fourRelatedRepeatEntries(),
        ),
        isNull,
      );
    });
  });

  group('PatternChangedGates', () {
    test('hidden during first-three activation', () {
      final result = PatternChangedEngine.build(
        changeProof: _proofForChoice(RepeatReturnCheckChoice.changed),
        records: [
          _answeredRecord(
            entryId: 'e3',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        entries: _threeRelatedRepeatEntries(),
      );
      expect(
        PatternChangedGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          viewingConfirmedRepeat: true,
          patternChanged: result,
          dismissed: false,
        ),
        isFalse,
      );
    });

    test('hidden while recording', () {
      final result = PatternChangedEngine.build(
        changeProof: _proofForChoice(RepeatReturnCheckChoice.changed),
        records: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        entries: _fourRelatedRepeatEntries(),
      );
      expect(
        PatternChangedGates.shouldShow(
          loaded: true,
          entryCount: 4,
          isReady: true,
          isRecording: true,
          isPostSave: false,
          viewingConfirmedRepeat: true,
          patternChanged: result,
          dismissed: false,
        ),
        isFalse,
      );
    });
  });

  group('PatternChangedCopy', () {
    test('uses grounded evidence language', () {
      final joined = [
        PatternChangedCopy.title,
        PatternChangedCopy.bodyFallback,
        PatternChangedCopy.footer,
        PatternChangedCopy.bodyWithPhrases('said yes again', 'walked outside'),
      ].join(' ').toLowerCase();

      expect(joined, contains('earlier'));
      expect(joined, contains('this time'));
      expect(joined, contains('noticed'));
      expect(joined, isNot(contains('you should')));
      expect(joined, isNot(contains('try repeating')));
    });

    test('no therapy or diagnosis language', () {
      for (final copy in [
        PatternChangedCopy.title,
        PatternChangedCopy.bodyFallback,
        PatternChangedCopy.footer,
        PatternChangedCopy.recordIfReturnsCta,
      ]) {
        _expectNoDiagnosticLanguage(copy);
        _expectNoAdviceLanguage(copy);
      }
    });

    test('main proof surfaces pass advice guard', () {
      for (final copy in ProofSurfaceAdviceGuard.mainProofSurfaceCopyBlocks()) {
        expect(ProofSurfaceAdviceGuard.passes(copy), isTrue, reason: copy);
      }
    });
  });

  group('PatternChangedCard', () {
    testWidgets('shows phrase evidence rows when grounded', (tester) async {
      final result = PatternChangedEngine.build(
        changeProof: _proofForChoice(RepeatReturnCheckChoice.changed),
        records: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        entries: _fourWithDifferentLatestPhrase(),
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatternChangedCard.test(
              result: result,
              entryCount: 4,
              surface: 'record',
              onRecord: () {},
            ),
          ),
        ),
      );

      expect(find.text(PatternChangedCopy.title), findsOneWidget);
      expect(find.text(PatternChangedCopy.earlierLabel), findsOneWidget);
      expect(find.text(PatternChangedCopy.thisTimeLabel), findsOneWidget);
      expect(find.text(PatternChangedCopy.footer), findsOneWidget);
      expect(find.text(PatternChangedCopy.recordIfReturnsCta), findsOneWidget);
    });

    testWidgets('shows fallback body when phrase evidence is weak', (
      tester,
    ) async {
      final result = PatternChangedEngine.build(
        changeProof: _proofForChoice(RepeatReturnCheckChoice.changed),
        records: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        entries: _fourRelatedRepeatEntries(),
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatternChangedCard.test(
              result: result,
              entryCount: 4,
              surface: 'patterns',
            ),
          ),
        ),
      );

      expect(find.text(PatternChangedCopy.bodyFallback), findsOneWidget);
      expect(find.text(PatternChangedCopy.earlierLabel), findsNothing);
    });

    testWidgets('CTA triggers record callback', (tester) async {
      final result = PatternChangedEngine.build(
        changeProof: _proofForChoice(RepeatReturnCheckChoice.changed),
        records: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        entries: _fourRelatedRepeatEntries(),
      )!;
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatternChangedCard.test(
              result: result,
              entryCount: 4,
              surface: 'record',
              onRecord: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('pattern_changed_record_cta')));
      expect(tapped, isTrue);
    });

    testWidgets('dismiss hides card', (tester) async {
      final prefs = _MemoryPrefs();
      final store = PatternChangedStore(prefs);
      final result = PatternChangedEngine.build(
        changeProof: _proofForChoice(RepeatReturnCheckChoice.changed),
        records: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        entries: _fourRelatedRepeatEntries(),
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatternChangedCard(
              result: result,
              entryCount: 4,
              surface: 'record',
              store: store,
              skipPrefsLoad: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('pattern_changed_dismiss')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pattern_changed_card_hidden')),
        findsOneWidget,
      );
      expect(
        PatternChangedStore.isDismissed(
          entryId: result.entryId,
          type: result.type,
        ),
        isTrue,
      );
    });
  });

  group('PatternChangedAnalytics', () {
    test('metadata only without transcript text', () {
      Map<String, Object>? captured;
      PatternChangedAnalytics.captureForTest = (event, props) {
        captured = props;
      };

      PatternChangedAnalytics.seen(
        surface: 'record',
        entryCount: 4,
        changeType: PatternChangedType.changed,
      );

      expect(captured, isNotNull);
      expect(
        captured!.keys,
        containsAll(['surface', 'entry_count', 'change_type']),
      );
      expect(captured!.keys, isNot(contains('transcript')));
      expect(captured!['change_type'], 'changed');
    });
  });

  group('Pattern changed dedup', () {
    test(
      'no duplicate change proof copy when pattern changed replaces proof',
      () {
        final proof = _proofForChoice(RepeatReturnCheckChoice.changed);
        final patternChanged = PatternChangedEngine.build(
          changeProof: proof,
          records: [
            _answeredRecord(
              entryId: 'e4',
              choice: RepeatReturnCheckChoice.changed,
            ),
          ],
          entries: _fourRelatedRepeatEntries(),
        )!;

        final layout = ArchiveProofSurfaceLayout(
          confirmedRepeatCardVisible: true,
          timelineVisible: false,
          changeProofVisible: true,
          proBridgeVisible: false,
          patternChangedVisible: true,
        );

        expect(layout.effectiveChangeProofVisible, isFalse);
        expect(layout.effectivePatternChangedVisible, isTrue);

        final blocks = ArchiveProofSurfaceCopy.patternsStack(
          layout: layout,
          changeProof: proof,
          patternChanged: patternChanged,
        );

        expect(blocks, contains(PatternChangedCopy.title));
        expect(blocks, isNot(contains(RepeatReturnCheckCopy.changeProofTitle)));
        expect(
          blocks,
          isNot(contains(RepeatReturnCheckCopy.trendSofterThanBefore)),
        );
        expect(
          blocks.where((block) => block == PatternChangedCopy.title),
          hasLength(1),
        );
      },
    );

    test('title differs from WhatChangedSinceLastTime on Patterns', () {
      expect(
        PatternChangedCopy.title,
        isNot(WhatChangedSinceLastTimeCopy.title),
      );
      expect(
        PatternChangedCopy.title,
        isNot(WhatChangedSinceLastTimeCopy.changedSummary),
      );
    });

    test('record layout keeps pattern changed above folded summary copy', () {
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: false,
        timelineVisible: false,
        changeProofVisible: true,
        proBridgeVisible: false,
        patternChangedVisible: true,
        archiveSummaryVisible: true,
      );

      expect(layout.recordPatternChangedVisible, isTrue);
      expect(layout.effectivePatternChangedVisible, isFalse);
    });

    test(
      'folds into Archive Summary without duplicate pattern changed card',
      () {
        final layout = ArchiveProofSurfaceLayout(
          confirmedRepeatCardVisible: false,
          timelineVisible: false,
          changeProofVisible: true,
          proBridgeVisible: false,
          patternChangedVisible: true,
          archiveSummaryVisible: true,
        );

        expect(layout.effectivePatternChangedVisible, isFalse);
        final blocks = ArchiveProofSurfaceCopy.patternsStack(layout: layout);
        expect(blocks, isNot(contains(PatternChangedCopy.title)));
        expect(blocks, isNot(contains(RepeatReturnCheckCopy.changeProofTitle)));
      },
    );
  });

  group('Record proof stack priority', () {
    test('pattern changed outranks archive summary when cap forces choice', () {
      final decision = RecordProofStackPolicy.decide(
        loaded: true,
        entryCount: 5,
        isReady: true,
        isPostSave: false,
        isRecording: false,
        archiveSummaryVisible: true,
        hasEarlyFirstSignal: false,
        hasEarlyEvidenceTimeline: false,
        patternChangedVisible: true,
        dailyReturnReasonEligible: true,
        weeklyReviewEligible: false,
        privateReportEligible: false,
        whyMattersEligible: false,
        thoughtMapEligible: false,
        positiveReinforcementEligible: false,
        changeProofEligible: false,
        firstWeekLoopEligible: true,
        proBridgeEligible: true,
      );

      expect(decision.showPatternChanged, isTrue);
      expect(decision.showArchiveSummary, isFalse);
      expect(decision.proofCardCount, lessThanOrEqualTo(3));
    });
  });
}
