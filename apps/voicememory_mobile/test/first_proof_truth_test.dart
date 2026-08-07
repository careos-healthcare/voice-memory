import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:voicememory_mobile/features/beta_activation/beta_activation_summary_engine.dart';
import 'package:voicememory_mobile/features/beta_activation/beta_activation_summary_tracker.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_analytics.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_copy.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_gates.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_model.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/widgets/record/first_proof_truth_card.dart';
import 'support/test_storage_sandbox.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? localAudioPath,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: localAudioPath,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _threeRelatedEntries() => [
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

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    FirstProofTruthAnalytics.resetForTest();
    ActivationFunnelAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await FirstProofTruthStore.resetForTest(AppServices.instance.prefs);
    await BetaActivationSummaryTracker.clearExtension();
  });

  tearDown(() => sandbox.dispose());
  tearDown(() async {
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/first_proof_truth/${DateTime.now().microsecondsSinceEpoch}_tear.json',
    );
  });

  group('FirstProofTruthGates', () {
    test('shows only with first proof payoff and unanswered proof key', () {
      final entries = _threeRelatedEntries();
      final payoff = FirstProofPayoffEngine.build(entries: entries);
      final proofKey = FirstProofTruthGates.proofKeyForEntries(entries);

      expect(payoff, isNotNull);
      expect(proofKey, 'e1|e2|e3');
      expect(
        FirstProofTruthGates.shouldShow(
          showFirstProofPayoff: true,
          payoff: payoff,
          entries: entries,
          proofKey: proofKey,
          hasAnsweredForProof: false,
        ),
        isTrue,
      );
      expect(
        FirstProofTruthGates.shouldShow(
          showFirstProofPayoff: false,
          payoff: payoff,
          entries: entries,
          proofKey: proofKey,
          hasAnsweredForProof: false,
        ),
        isFalse,
      );
      expect(
        FirstProofTruthGates.shouldShow(
          showFirstProofPayoff: true,
          payoff: payoff,
          entries: entries,
          proofKey: proofKey,
          hasAnsweredForProof: true,
        ),
        isFalse,
      );
    });

    test('hides for generic test quiet pending entries via payoff gate', () {
      final generic = [
        _entry(id: 'g1', transcript: 'This is a test to check function'),
        _entry(id: 'g2', transcript: 'This is a second test for pressure'),
        _entry(id: 'g3', transcript: 'This is a third test for pressure'),
      ];
      final quiet = [
        _entry(id: 'q1', transcript: 'Nothing much today.'),
        _entry(id: 'q2', transcript: 'Nothing much today.'),
        _entry(id: 'q3', transcript: 'Nothing much today.'),
      ];
      final pending = [
        _entry(
          id: 'v1',
          transcript: _placeholder,
          localAudioPath: '/tmp/v1.m4a',
        ),
        _entry(
          id: 'v2',
          transcript: _placeholder,
          localAudioPath: '/tmp/v2.m4a',
        ),
        _entry(
          id: 'v3',
          transcript: _placeholder,
          localAudioPath: '/tmp/v3.m4a',
        ),
      ];

      for (final entries in [generic, quiet, pending]) {
        final payoff = FirstProofPayoffEngine.build(entries: entries);
        final proofKey = FirstProofTruthGates.proofKeyForEntries(entries);
        expect(
          FirstProofTruthGates.shouldShow(
            showFirstProofPayoff: payoff != null,
            payoff: payoff,
            entries: entries,
            proofKey: proofKey,
            hasAnsweredForProof: false,
          ),
          isFalse,
        );
      }
    });
  });

  group('FirstProofTruthStore', () {
    test('Yes Sort of No store local answer by proof key', () async {
      const proofKey = 'e1|e2|e3';
      final store = FirstProofTruthStore.forPrefs(AppServices.instance.prefs);

      await store.saveAnswer(
        proofKey: proofKey,
        answer: FirstProofTruthAnswer.yes,
      );
      await FirstProofTruthStore.ensureLoaded();
      expect(FirstProofTruthStore.hasAnswered(proofKey), isTrue);
      expect(
        FirstProofTruthStore.answerFor(proofKey),
        FirstProofTruthAnswer.yes,
      );

      await FirstProofTruthStore.resetForTest(AppServices.instance.prefs);
      await FirstProofTruthStore.ensureLoaded();

      await store.saveAnswer(
        proofKey: proofKey,
        answer: FirstProofTruthAnswer.sortOf,
      );
      await FirstProofTruthStore.ensureLoaded();
      expect(
        FirstProofTruthStore.answerFor(proofKey),
        FirstProofTruthAnswer.sortOf,
      );
    });
  });

  group('FirstProofTruthCard', () {
    testWidgets('answering hides question for action loop handoff', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofTruthCard.test(
              proofKey: 'e1|e2|e3',
              entryCount: 3,
              hasSnippets: true,
            ),
          ),
        ),
      );

      expect(find.text(FirstProofTruthCopy.question), findsOneWidget);
      await tester.tap(find.byKey(const Key('first_proof_truth_yes')));
      await tester.pump();

      expect(find.text(FirstProofTruthCopy.question), findsNothing);
      expect(find.text(FirstProofTruthCopy.afterYes), findsNothing);
      expect(
        find.byKey(const Key('first_proof_truth_answered')),
        findsOneWidget,
      );
    });

    testWidgets('already answered proof hides card content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofTruthCard.test(
              proofKey: 'e1|e2|e3',
              entryCount: 3,
              hasSnippets: false,
              initialAnswer: FirstProofTruthAnswer.no,
            ),
          ),
        ),
      );

      expect(find.text(FirstProofTruthCopy.question), findsNothing);
      expect(find.text(FirstProofTruthCopy.afterNo), findsNothing);
      expect(
        find.byKey(const Key('first_proof_truth_answered')),
        findsOneWidget,
      );
    });
  });

  group('FirstProofTruthAnalytics', () {
    test('payload excludes transcript and pattern text', () {
      final captured = <({String event, Map<String, Object> props})>[];
      ActivationFunnelAnalytics.captureForTest((event, props) {
        captured.add((event: event, props: props));
      });

      FirstProofTruthAnalytics.answered(
        source: 'record',
        entryCount: 3,
        answer: 'sort_of',
        hasSnippets: true,
      );

      expect(captured.length, 1);
      expect(captured.first.event, FirstProofTruthAnalytics.answeredEvent);
      const allowedKeys = {'source', 'entry_count', 'answer', 'has_snippets'};
      expect(captured.first.props.keys.toSet(), allowedKeys);
      final values = captured.first.props.values
          .map((v) => v.toString().toLowerCase())
          .join(' ');
      expect(values, isNot(contains('said yes')));
      expect(values, isNot(contains('capacity')));
      expect(captured.first.props['answer'], 'sort_of');
      expect(captured.first.props['has_snippets'], 1);
    });
  });

  group('Beta activation summary', () {
    test('truth answer increments counts only', () async {
      await BetaActivationSummaryTracker.trackFirstProofTruthAnswer(
        FirstProofTruthAnswer.yes,
      );
      await BetaActivationSummaryTracker.trackFirstProofTruthAnswer(
        FirstProofTruthAnswer.sortOf,
      );
      await BetaActivationSummaryTracker.trackFirstProofTruthAnswer(
        FirstProofTruthAnswer.no,
      );

      final extension = await BetaActivationSummaryTracker.loadExtension();
      expect(extension.firstProofTruthYes, 1);
      expect(extension.firstProofTruthSortOf, 1);
      expect(extension.firstProofTruthNo, 1);

      final copy = BetaActivationSummaryEngine.buildCopyText(
        BetaActivationSummaryEngine.build(
          loop: const BetaActivationLoopCounts(),
          extension: extension,
        ),
      );
      expect(copy, contains('First proof truth: yes'));
      expect(copy, contains('First proof truth: sort of'));
      expect(copy, contains('First proof truth: no'));
      expect(copy.toLowerCase(), isNot(contains('said yes')));
      expect(copy.toLowerCase(), isNot(contains('transcript:')));
      expect(copy.toLowerCase(), isNot(contains('pattern name')));
    });
  });

  group('Protected areas', () {
    test('feature files avoid billing and signing surfaces', () {
      const banned = ['RevenueCat', 'Purchases.', 'CFBundleVersion', 'signing'];
      final files = [
        'lib/features/first_proof_truth/first_proof_truth_copy.dart',
        'lib/features/first_proof_truth/first_proof_truth_store.dart',
        'lib/features/first_proof_truth/first_proof_truth_analytics.dart',
        'lib/widgets/record/first_proof_truth_card.dart',
      ];
      for (final path in files) {
        final text = File(path).readAsStringSync();
        for (final token in banned) {
          expect(
            text.contains(token),
            isFalse,
            reason: '$path must not reference $token',
          );
        }
      }
    });
  });
}
