import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_proof_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_check_answer_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_check_answer_copy.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_check_answer_engine.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_check_answer_gates.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_check_answer_model.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_copy.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_engine.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_gates.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_model.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';

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

PostSaveReturnCheckAnswer _requireAnswer(List<JournalEntry> entries) {
  final answer = PostSaveReturnCheckAnswerEngine.build(
    entries: entries,
    returnChecks: const [],
  );
  expect(answer, isNotNull);
  return answer!;
}

void main() {
  setUp(() async {
    EarlyArchiveProofAnalytics.resetForTest();
    ActivationFunnelAnalytics.resetForTest();
    await RepeatReturnCheckStore.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_psrca.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  group('PostSaveReturnCheckAnswerEngine', () {
    test('hidden at entryCount 0–3', () {
      for (final count in [1, 2, 3]) {
        expect(
          PostSaveReturnCheckAnswerEngine.build(
            entries: _threeRelatedRepeatEntries().take(count).toList(),
            returnChecks: const [],
          ),
          isNull,
        );
      }
    });

    test('shown after fourth related post-save when unanswered', () {
      final answer = _requireAnswer(_fourRelatedRepeatEntries());
      expect(answer.title, PostSaveReturnCheckAnswerCopy.title);
      expect(answer.entryId, 'e4');
    });

    test('hidden after answer already exists', () {
      expect(
        PostSaveReturnCheckAnswerEngine.build(
          entries: _fourRelatedRepeatEntries(),
          returnChecks: [
            _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
          ],
        ),
        isNull,
      );
    });

    test('hidden for unrelated fourth entry', () {
      final entries = [
        ..._threeRelatedRepeatEntries(),
        _entry(
          id: 'e4',
          transcript: 'Completely unrelated topic about gardening today.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
      ];
      expect(
        PostSaveReturnCheckAnswerEngine.build(
          entries: entries,
          returnChecks: const [],
        ),
        isNull,
      );
    });

    test('phrase body uses concrete phrase', () {
      final answer = _requireAnswer(_fourRelatedRepeatEntries());
      expect(answer.hasPhrase, isTrue);
      expect(answer.body, contains('said yes'));
      expect(answer.body, startsWith('ArchiveMe matched this to “'));
    });

    test('fallback body when phrase unavailable', () {
      final entries = [
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
        _entry(
          id: 'e4',
          transcript:
              'I said yes again even though I had no capacity for one more ask today.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
      ];
      final answer = PostSaveReturnCheckAnswerEngine.build(
        entries: entries,
        returnChecks: const [],
      );
      expect(answer, isNotNull);
      if (!answer!.hasPhrase) {
        expect(answer.body, PostSaveReturnCheckAnswerCopy.bodyFallback);
      }
    });
  });

  group('PostSaveReturnCheckAnswerGates', () {
    test('hidden on ready state and degraded post-save', () {
      final answer = _requireAnswer(_fourRelatedRepeatEntries());

      expect(
        PostSaveReturnCheckAnswerGates.shouldShow(
          isPostSaveDone: false,
          entryCount: 4,
          isDegradedPostSave: false,
          showFirstProofMoment: false,
          answer: answer,
        ),
        isFalse,
      );
      expect(
        PostSaveReturnCheckAnswerGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 4,
          isDegradedPostSave: true,
          showFirstProofMoment: false,
          answer: answer,
        ),
        isFalse,
      );
    });

    test('hidden when first proof moment is showing', () {
      final answer = _requireAnswer(_fourRelatedRepeatEntries());

      expect(
        PostSaveReturnCheckAnswerGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 4,
          isDegradedPostSave: false,
          showFirstProofMoment: true,
          answer: answer,
        ),
        isFalse,
      );
    });
  });

  group('PostSaveReturnCheckAnswer persistence', () {
    test('Softer answer updates payoff to softer copy', () async {
      final store = RepeatReturnCheckStore.instance();
      await store.saveChoice(
        entryId: 'e4',
        choice: PostSaveReturnCheckAnswerChoice.softer.storageChoice,
        entryCountAtCapture: 4,
      );

      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: RepeatReturnCheckStore.cached,
      );
      expect(payoff!.state, ReturnCheckPayoffComparisonState.softer);
      expect(payoff.title, ReturnCheckPayoffCopy.softerTitle);
    });

    test('Stronger answer updates payoff to stronger copy', () async {
      final store = RepeatReturnCheckStore.instance();
      await store.saveChoice(
        entryId: 'e4',
        choice: PostSaveReturnCheckAnswerChoice.stronger.storageChoice,
        entryCountAtCapture: 4,
      );

      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: RepeatReturnCheckStore.cached,
      );
      expect(payoff!.state, ReturnCheckPayoffComparisonState.stronger);
      expect(payoff.title, ReturnCheckPayoffCopy.strongerTitle);
    });

    test('About the same answer updates payoff to same copy', () async {
      final store = RepeatReturnCheckStore.instance();
      await store.saveChoice(
        entryId: 'e4',
        choice: PostSaveReturnCheckAnswerChoice.same.storageChoice,
        entryCountAtCapture: 4,
      );

      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: RepeatReturnCheckStore.cached,
      );
      expect(payoff!.state, ReturnCheckPayoffComparisonState.same);
      expect(payoff.title, ReturnCheckPayoffCopy.sameTitle);
    });

    test('Different answer updates payoff to changed copy', () async {
      final store = RepeatReturnCheckStore.instance();
      await store.saveChoice(
        entryId: 'e4',
        choice: PostSaveReturnCheckAnswerChoice.different.storageChoice,
        entryCountAtCapture: 4,
      );

      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: RepeatReturnCheckStore.cached,
      );
      expect(payoff!.state, ReturnCheckPayoffComparisonState.changed);
      expect(payoff.title, ReturnCheckPayoffCopy.changedTitle);
    });
  });

  group('Return check payoff integration', () {
    test('unknown payoff is hidden while answer question is visible', () {
      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: const [],
      );
      expect(payoff!.state, ReturnCheckPayoffComparisonState.unknown);

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

    test('resolved payoff shows after answer is stored', () async {
      final store = RepeatReturnCheckStore.instance();
      await store.saveChoice(
        entryId: 'e4',
        choice: RepeatReturnCheckChoice.stronger,
        entryCountAtCapture: 4,
      );

      expect(
        PostSaveReturnCheckAnswerEngine.build(
          entries: _fourRelatedRepeatEntries(),
          returnChecks: RepeatReturnCheckStore.cached,
        ),
        isNull,
      );

      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: RepeatReturnCheckStore.cached,
      );
      expect(payoff!.state, ReturnCheckPayoffComparisonState.stronger);
      expect(
        ReturnCheckPayoffGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 4,
          isDegradedPostSave: false,
          showFirstProofMoment: false,
          showPostSaveReturnCheckAnswer: false,
          payoff: payoff,
        ),
        isTrue,
      );
    });
  });

  group('PostSaveReturnCheckAnswerAnalytics', () {
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
      PostSaveReturnCheckAnswerAnalytics.seen(
        entryCount: 4,
        hasPhrase: true,
        hasConfirmedRepeat: true,
      );
      PostSaveReturnCheckAnswerAnalytics.tapped(
        entryCount: 4,
        answer: PostSaveReturnCheckAnswerChoice.softer,
        hasPhrase: true,
        hasConfirmedRepeat: true,
      );

      expect(captured, hasLength(2));
      expect(
        captured.first.event,
        EarlyArchiveProofAnalytics.postSaveReturnCheckAnswerSeenEvent,
      );
      for (final item in captured) {
        expect(item.properties.keys, contains('entry_count'));
        expect(item.properties.keys, contains('source'));
        expect(item.properties.keys, isNot(contains('transcript')));
        expect(item.properties.keys, isNot(contains('phrase')));
        expect(item.properties.values.join(' '), isNot(contains('said yes')));
      }

      final tapped = captured.last;
      expect(tapped.event, EarlyArchiveProofAnalytics.postSaveReturnCheckAnswerTappedEvent);
      expect(tapped.properties['answer'], 'softer');
    });
  });

  group('PostSaveReturnCheckAnswerCopy guard', () {
    test('copy avoids therapy diagnosis and personality claims', () {
      for (final copy in [
        PostSaveReturnCheckAnswerCopy.label,
        PostSaveReturnCheckAnswerCopy.title,
        PostSaveReturnCheckAnswerCopy.bodyFallback,
        PostSaveReturnCheckAnswerCopy.footer,
        ...PostSaveReturnCheckAnswerChoice.values.map((c) => c.label),
      ]) {
        _expectNoDiagnosticLanguage(copy);
      }
    });

    test('footer says one tap is enough', () {
      expect(PostSaveReturnCheckAnswerCopy.footer, 'One tap is enough.');
    });
  });

  group('Record screen isolation', () {
    test('record screen does not import post save return check answer card', () {
      final source = File(
        'lib/screens/record_screen.dart',
      ).readAsStringSync();
      expect(source.contains('post_save_return_check_answer'), isFalse);
      expect(source.contains('PostSaveReturnCheckAnswerCard'), isFalse);
      expect(source.contains('what_changed_v2_card'), isTrue);
    });
  });

  group('Billing isolation', () {
    test('billing RevenueCat restore untouched', () {
      final cardSource = File(
        'lib/widgets/record/post_save_return_check_answer_card.dart',
      ).readAsStringSync();
      expect(cardSource.toLowerCase(), isNot(contains('revenuecat')));
      expect(cardSource.toLowerCase(), isNot(contains('restorepurchase')));
      expect(cardSource.toLowerCase(), isNot(contains('billing')));

      final cardUsesOutlinedOnly =
          cardSource.contains('OutlinedButton') &&
          !cardSource.contains('FilledButton') &&
          !cardSource.contains('ElevatedButton');
      expect(cardUsesOutlinedOnly, isTrue);
    });
  });
}
