import 'dart:io';

import 'package:archiveme_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:archiveme_mobile/features/beta_activation/beta_activation_summary_engine.dart';
import 'package:archiveme_mobile/features/beta_activation/beta_activation_summary_tracker.dart';
import 'package:archiveme_mobile/features/first_proof_action_loop/first_proof_action_loop_analytics.dart';
import 'package:archiveme_mobile/features/first_proof_action_loop/first_proof_action_loop_copy.dart';
import 'package:archiveme_mobile/features/first_proof_action_loop/first_proof_action_loop_engine.dart';
import 'package:archiveme_mobile/features/first_proof_action_loop/first_proof_action_loop_gates.dart';
import 'package:archiveme_mobile/features/first_proof_action_loop/first_proof_action_loop_model.dart';
import 'package:archiveme_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:archiveme_mobile/features/first_proof_truth/first_proof_truth_model.dart';
import 'package:archiveme_mobile/features/first_proof_truth/first_proof_truth_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/widgets/record/first_proof_action_loop_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    FirstProofActionLoopAnalytics.resetForTest();
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
  group('FirstProofActionLoopEngine', () {
    test('Yes answer shows watch this next and view pattern details', () {
      final entries = _threeRelatedEntries();
      final payoff = FirstProofPayoffEngine.build(entries: entries)!;

      final content = FirstProofActionLoopEngine.build(
        answer: FirstProofTruthAnswer.yes,
        entries: entries,
        payoff: payoff,
      );

      expect(content, isNotNull);
      expect(content!.title, FirstProofActionLoopCopy.yesTitle);
      expect(content.actions, contains(FirstProofActionType.watchThisNext));
      expect(
        content.actions,
        contains(FirstProofActionType.viewPatternDetails),
      );
    });

    test('Sort of answer shows rename pattern and keep recording', () {
      final entries = _threeRelatedEntries();
      final payoff = FirstProofPayoffEngine.build(entries: entries)!;

      final content = FirstProofActionLoopEngine.build(
        answer: FirstProofTruthAnswer.sortOf,
        entries: entries,
        payoff: payoff,
      );

      expect(content, isNotNull);
      expect(content!.title, FirstProofActionLoopCopy.sortOfTitle);
      expect(content.actions, contains(FirstProofActionType.renamePattern));
      expect(content.actions, contains(FirstProofActionType.keepRecording));
    });

    test('No answer shows correct transcript remove and keep recording', () {
      final entries = _threeRelatedEntries();
      final payoff = FirstProofPayoffEngine.build(entries: entries)!;

      final content = FirstProofActionLoopEngine.build(
        answer: FirstProofTruthAnswer.no,
        entries: entries,
        payoff: payoff,
      );

      expect(content, isNotNull);
      expect(content!.title, FirstProofActionLoopCopy.noTitle);
      expect(content.actions, contains(FirstProofActionType.correctTranscript));
      expect(content.actions, contains(FirstProofActionType.removeFromPattern));
      expect(content.actions, contains(FirstProofActionType.keepRecording));
    });
  });

  group('FirstProofActionLoopGates', () {
    test('shows only after first proof payoff and truth answer', () {
      final entries = _threeRelatedEntries();
      final payoff = FirstProofPayoffEngine.build(entries: entries);
      const proofKey = 'e1|e2|e3';

      expect(
        FirstProofActionLoopGates.shouldShow(
          showFirstProofPayoff: true,
          payoff: payoff,
          proofKey: proofKey,
          hasAnsweredForProof: true,
        ),
        isTrue,
      );
      expect(
        FirstProofActionLoopGates.shouldShow(
          showFirstProofPayoff: true,
          payoff: payoff,
          proofKey: proofKey,
          hasAnsweredForProof: false,
        ),
        isFalse,
      );
      expect(
        FirstProofActionLoopGates.shouldShow(
          showFirstProofPayoff: false,
          payoff: payoff,
          proofKey: proofKey,
          hasAnsweredForProof: true,
        ),
        isFalse,
      );
    });

    test('does not show before first proof', () {
      expect(
        FirstProofActionLoopGates.shouldShow(
          showFirstProofPayoff: false,
          payoff: null,
          proofKey: '',
          hasAnsweredForProof: true,
        ),
        isFalse,
      );
    });

    test('does not show for generic quiet pending entries via payoff gate', () {
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
        expect(
          FirstProofActionLoopGates.shouldShow(
            showFirstProofPayoff: payoff != null,
            payoff: payoff,
            proofKey: 'a|b|c',
            hasAnsweredForProof: true,
          ),
          isFalse,
        );
      }
    });
  });

  group('FirstProofActionLoopCard', () {
    testWidgets('Yes answer shows watch this next and view pattern details', (
      tester,
    ) async {
      final entries = _threeRelatedEntries();
      final payoff = FirstProofPayoffEngine.build(entries: entries)!;
      final content = FirstProofActionLoopEngine.build(
        answer: FirstProofTruthAnswer.yes,
        entries: entries,
        payoff: payoff,
      )!;

      var watched = false;
      var viewed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofActionLoopCard(
              content: content,
              entryCount: 3,
              onWatchThisNext: () => watched = true,
              onViewPatternDetails: () => viewed = true,
            ),
          ),
        ),
      );

      expect(find.text(FirstProofActionLoopCopy.yesTitle), findsOneWidget);
      expect(
        find.text(FirstProofActionLoopCopy.watchThisNextCta),
        findsOneWidget,
      );
      expect(
        find.text(FirstProofActionLoopCopy.viewPatternDetailsCta),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('first_proof_action_loop_watch_this_next')),
      );
      await tester.pump();
      expect(watched, isTrue);

      await tester.tap(
        find.byKey(const Key('first_proof_action_loop_view_pattern_details')),
      );
      await tester.pump();
      expect(viewed, isTrue);
    });

    testWidgets('Sort of answer shows rename pattern and keep recording', (
      tester,
    ) async {
      final entries = _threeRelatedEntries();
      final payoff = FirstProofPayoffEngine.build(entries: entries)!;
      final content = FirstProofActionLoopEngine.build(
        answer: FirstProofTruthAnswer.sortOf,
        entries: entries,
        payoff: payoff,
      )!;

      var renamed = false;
      var keptRecording = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofActionLoopCard(
              content: content,
              entryCount: 3,
              onWatchThisNext: () {},
              onRenamePattern: () => renamed = true,
              onKeepRecording: () => keptRecording = true,
            ),
          ),
        ),
      );

      expect(find.text(FirstProofActionLoopCopy.sortOfTitle), findsOneWidget);
      expect(
        find.text(FirstProofActionLoopCopy.renamePatternCta),
        findsOneWidget,
      );
      expect(
        find.text(FirstProofActionLoopCopy.keepRecordingCta),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('first_proof_action_loop_rename_pattern')),
      );
      await tester.pump();
      expect(renamed, isTrue);

      await tester.tap(
        find.byKey(const Key('first_proof_action_loop_keep_recording')),
      );
      await tester.pump();
      expect(keptRecording, isTrue);
    });

    testWidgets(
      'No answer shows correct transcript remove and keep recording',
      (tester) async {
        final entries = _threeRelatedEntries();
        final payoff = FirstProofPayoffEngine.build(entries: entries)!;
        final content = FirstProofActionLoopEngine.build(
          answer: FirstProofTruthAnswer.no,
          entries: entries,
          payoff: payoff,
        )!;

        var corrected = false;
        var removed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FirstProofActionLoopCard(
                content: content,
                entryCount: 3,
                onWatchThisNext: () {},
                onCorrectTranscript: () => corrected = true,
                onRemoveFromPattern: () => removed = true,
                onKeepRecording: () {},
              ),
            ),
          ),
        );

        expect(find.text(FirstProofActionLoopCopy.noTitle), findsOneWidget);
        expect(
          find.text(FirstProofActionLoopCopy.correctTranscriptCta),
          findsOneWidget,
        );
        expect(
          find.text(FirstProofActionLoopCopy.removeFromPatternCta),
          findsOneWidget,
        );
        expect(
          find.text(FirstProofActionLoopCopy.keepRecordingCta),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('first_proof_action_loop_correct_transcript')),
        );
        await tester.pump();
        expect(corrected, isTrue);
        expect(removed, isFalse);

        await tester.tap(
          find.byKey(const Key('first_proof_action_loop_remove_from_pattern')),
        );
        await tester.pump();
        expect(removed, isTrue);
      },
    );
  });

  group('FirstProofActionLoopAnalytics', () {
    test('payload excludes transcript and pattern text', () {
      final captured = <({String event, Map<String, Object> props})>[];
      ActivationFunnelAnalytics.captureForTest((event, props) {
        captured.add((event: event, props: props));
      });

      FirstProofActionLoopAnalytics.selected(
        source: 'record',
        entryCount: 3,
        answer: 'no',
        action: FirstProofActionType.removeFromPattern,
      );

      expect(captured.length, 1);
      expect(captured.first.event, FirstProofActionLoopAnalytics.selectedEvent);
      const allowedKeys = {'source', 'entry_count', 'answer', 'action_type'};
      expect(captured.first.props.keys.toSet(), allowedKeys);
      final values = captured.first.props.values
          .map((v) => v.toString().toLowerCase())
          .join(' ');
      expect(values, isNot(contains('said yes')));
      expect(values, isNot(contains('capacity')));
      expect(captured.first.props['action_type'], 'remove_from_pattern');
    });
  });

  group('Beta activation summary', () {
    test('action selected increments counts by action type', () async {
      await BetaActivationSummaryTracker.trackFirstProofActionSelected(
        FirstProofActionType.watchThisNext,
      );
      await BetaActivationSummaryTracker.trackFirstProofActionSelected(
        FirstProofActionType.renamePattern,
      );
      await BetaActivationSummaryTracker.trackFirstProofActionSelected(
        FirstProofActionType.removeFromPattern,
      );

      final extension = await BetaActivationSummaryTracker.loadExtension();
      expect(extension.firstProofActionWatchThisNext, 1);
      expect(extension.firstProofActionRenamePattern, 1);
      expect(extension.firstProofActionRemoveFromPattern, 1);

      final copy = BetaActivationSummaryEngine.buildCopyText(
        BetaActivationSummaryEngine.build(
          loop: const BetaActivationLoopCounts(),
          extension: extension,
        ),
      );
      expect(copy, contains('First proof action: watch this next'));
      expect(copy, contains('First proof action: rename pattern'));
      expect(copy, contains('First proof action: remove from pattern'));
      expect(copy.toLowerCase(), isNot(contains('said yes')));
      expect(copy.toLowerCase(), isNot(contains('pattern name')));
    });
  });

  group('Protected areas', () {
    test('feature files avoid billing and signing surfaces', () {
      const banned = ['RevenueCat', 'Purchases.', 'CFBundleVersion', 'signing'];
      final files = [
        'lib/features/first_proof_action_loop/first_proof_action_loop_copy.dart',
        'lib/features/first_proof_action_loop/first_proof_action_loop_analytics.dart',
        'lib/widgets/record/first_proof_action_loop_card.dart',
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