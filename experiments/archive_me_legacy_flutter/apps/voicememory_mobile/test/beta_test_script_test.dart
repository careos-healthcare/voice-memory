import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_store.dart';
import 'package:voicememory_mobile/features/beta_test_script/beta_test_script_analytics.dart';
import 'package:voicememory_mobile/features/beta_test_script/beta_test_script_copy.dart';
import 'package:voicememory_mobile/features/beta_test_script/beta_test_script_engine.dart';
import 'package:voicememory_mobile/features/beta_test_script/beta_test_script_model.dart';
import 'package:voicememory_mobile/features/beta_test_script/beta_test_script_store.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_model.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/testing_archiveme_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/beta_test_script_card.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/beta_test_script/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

JournalEntry _entry(String id, String transcript, {DateTime? createdAt}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
      transcript: transcript,
      durationSeconds: 24,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up in this moment.',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _threeRelatedEntries() => [
  _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 10, 12)),
  _entry(
    '2',
    'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    '3',
    'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

void main() {
  setUp(() async {
    BetaTestScriptAnalytics.resetForTest();
    ArchiveBetaMissionGate.resetForTest();
    BetaTestScriptStore.seedForTest(null);
    await AppServices.resetForTest(
      journalPath:
          '${(await Directory.systemTemp.createTemp('vm_beta_script_')).path}/journal.json',
      prefsPath:
          '${(await Directory.systemTemp.createTemp('vm_beta_script_prefs_')).path}/prefs.json',
      skipRevenueCat: true,
    );
    await BetaFeedbackStore.resetForTest();
    await FirstProofTruthStore.resetForTest(AppServices.instance.prefs);
  });

  tearDown(() {
    BetaTestScriptAnalytics.resetForTest();
    ArchiveBetaMissionGate.resetForTest();
  });

  group('BetaTestScriptCopy', () {
    test('exact v1 copy', () {
      expect(BetaTestScriptCopy.settingsTileTitle, 'Early archive test');
      expect(BetaTestScriptCopy.screenTitle, 'ArchiveMe early test');
      expect(BetaTestScriptCopy.day1Title, 'Step 1 — Save one small moment');
      expect(
        BetaTestScriptCopy.day2Title,
        'Step 2 — Come back when something stands out',
      );
      expect(BetaTestScriptCopy.day3Title, 'Step 3 — See what returned');
      expect(
        BetaTestScriptCopy.compactBodyDay1,
        'Save one small moment when something stands out.',
      );
      expect(BetaTestScriptCopy.resetTitle, 'Reset early test progress?');
    });
  });

  group('BetaTestScriptGates', () {
    test('testing screen hidden when beta flag disabled', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(BetaTestScriptGates.shouldShowOnTestingScreen(), isFalse);
    });

    test('testing screen visible when beta flag enabled', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(BetaTestScriptGates.shouldShowOnTestingScreen(), isTrue);
    });

    test('compact card hidden during return-day question', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        BetaTestScriptGates.shouldShowCompactCardOnRecord(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          dismissed: false,
          showReturnDayFlow: true,
          firstProofLoopActive: false,
          showWhatChangedV2Display: false,
        ),
        isFalse,
      );
    });

    test('compact card hidden during first proof loop', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        BetaTestScriptGates.shouldShowCompactCardOnRecord(
          isReady: true,
          isRecording: false,
          isPostSave: true,
          dismissed: false,
          showReturnDayFlow: false,
          firstProofLoopActive: true,
          showWhatChangedV2Display: false,
        ),
        isFalse,
      );
    });

    test('compact card hidden during recording', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        BetaTestScriptGates.shouldShowCompactCardOnRecord(
          isReady: true,
          isRecording: true,
          isPostSave: false,
          dismissed: false,
          showReturnDayFlow: false,
          firstProofLoopActive: false,
          showWhatChangedV2Display: false,
        ),
        isFalse,
      );
    });

    test('compact card hidden when dismissed', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        BetaTestScriptGates.shouldShowCompactCardOnRecord(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          dismissed: true,
          showReturnDayFlow: false,
          firstProofLoopActive: false,
          showWhatChangedV2Display: false,
        ),
        isFalse,
      );
    });
  });

  group('BetaTestScriptEngine progress', () {
    test('progress inferred from entry count', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final zero = BetaTestScriptEngine.buildProgressSummary(entries: const []);
      expect(zero.day1Label, BetaTestScriptCopy.day1NotStarted);
      expect(zero.day2Label, BetaTestScriptCopy.day2Waiting);
      expect(zero.day3Label, BetaTestScriptCopy.day3Waiting);

      final one = BetaTestScriptEngine.buildProgressSummary(
        entries: [_entry('1', _strongRepeat)],
      );
      expect(one.day1Label, BetaTestScriptCopy.day1Done);
      expect(one.day2Label, BetaTestScriptCopy.day2Waiting);

      final two = BetaTestScriptEngine.buildProgressSummary(
        entries: [
          _entry('1', _strongRepeat),
          _entry('2', 'A quiet lunch with a friend today.'),
        ],
      );
      expect(two.day2Label, BetaTestScriptCopy.day2Done);
      expect(two.day3Label, BetaTestScriptCopy.day3Waiting);
    });

    test('first proof reached when three related entries exist', () {
      final progress = BetaTestScriptEngine.buildProgressSummary(
        entries: _threeRelatedEntries(),
      );
      expect(
        FirstProofPayoffEngine.build(entries: _threeRelatedEntries()),
        isNotNull,
      );
      expect(progress.firstProofLabel, BetaTestScriptCopy.firstProofReached);
    });

    test('truth answered status when first proof truth answered', () async {
      ArchiveBetaMissionGate.enabledOverride = true;
      final entries = _threeRelatedEntries();
      final proofKey = FirstProofTruthStore.proofKeyForFirstProof(entries);
      await FirstProofTruthStore.instance().saveAnswer(
        proofKey: proofKey,
        answer: FirstProofTruthAnswer.yes,
      );
      final card = BetaTestScriptEngine.buildCompactCard(entries: entries);
      expect(card?.phase, BetaTestScriptCompactPhase.complete);
      expect(card?.body, BetaTestScriptCopy.compactBodyComplete);
    });

    test('compact card copy by entry count', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        BetaTestScriptEngine.buildCompactCard(entries: const [])?.body,
        BetaTestScriptCopy.compactBodyDay1,
      );
      expect(
        BetaTestScriptEngine.buildCompactCard(
          entries: [_entry('1', _strongRepeat)],
        )?.body,
        BetaTestScriptCopy.compactBodyDay2,
      );
      expect(
        BetaTestScriptEngine.buildCompactCard(
          entries: [
            _entry('1', _strongRepeat),
            _entry('2', 'A quiet lunch with a friend today.'),
          ],
        )?.body,
        BetaTestScriptCopy.compactBodyDay3,
      );
      expect(
        BetaTestScriptEngine.buildCompactCard(
          entries: _threeRelatedEntries(),
        )?.body,
        BetaTestScriptCopy.compactBodyFirstProof,
      );
    });

    test('does not create fake entries', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      BetaTestScriptEngine.buildPlan(entries: const []);
      BetaTestScriptEngine.buildCompactCard(entries: const []);
      expect(
        BetaTestScriptEngine.buildProgressSummary(entries: const []).entryCount,
        0,
      );
    });
  });

  group('BetaTestScriptStore reset', () {
    test('reset beta test progress only clears tester script store', () async {
      final prefs = _MemoryPrefs();
      BetaTestScriptStore.seedForTest(
        const BetaTestScriptProgressRecord(
          day1Seen: true,
          day2Seen: true,
          day3Seen: true,
          dismissed: true,
          startedDateKey: '2026-06-10',
        ),
      );
      await BetaTestScriptStore.forPrefs(prefs).resetProgress();
      expect(BetaTestScriptStore.cached.day1Seen, isFalse);
      expect(BetaTestScriptStore.cached.day2Seen, isFalse);
      expect(BetaTestScriptStore.cached.day3Seen, isFalse);
      expect(BetaTestScriptStore.cached.dismissed, isFalse);
      expect(BetaTestScriptStore.cached.startedDateKey, isNull);
    });
  });

  group('TestingArchiveMeScreen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const TestingArchiveMeScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openBetaTestScriptSheet(WidgetTester tester) async {
      final button = find.byKey(const Key('testing_archiveme_view_test_steps'));
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('tile appears when beta flag enabled', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      await pumpScreen(tester);
      expect(
        find.byKey(const Key('testing_archiveme_beta_test_tile')),
        findsOneWidget,
      );
      expect(find.text(BetaTestScriptCopy.settingsTileTitle), findsOneWidget);
      expect(find.text(BetaTestScriptCopy.settingsTileBody), findsOneWidget);
    });

    testWidgets('tile hidden when beta flag disabled', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = false;
      await pumpScreen(tester);
      expect(
        find.byKey(const Key('testing_archiveme_beta_test_tile')),
        findsNothing,
      );
    });

    testWidgets('sheet opens with early archive plan', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      await pumpScreen(tester);
      await openBetaTestScriptSheet(tester);

      expect(find.byKey(const Key('beta_test_script_sheet')), findsOneWidget);
      expect(find.text(BetaTestScriptCopy.screenTitle), findsOneWidget);
      expect(find.text(BetaTestScriptCopy.day1Title), findsOneWidget);
      expect(find.text(BetaTestScriptCopy.day2Title), findsOneWidget);
      expect(find.text(BetaTestScriptCopy.day3Title), findsOneWidget);
    });

    testWidgets('success questions and failure signal render', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      await pumpScreen(tester);
      await openBetaTestScriptSheet(tester);

      expect(find.text(BetaTestScriptCopy.successHeading), findsOneWidget);
      for (final question in BetaTestScriptCopy.successQuestions) {
        expect(find.textContaining(question), findsOneWidget);
      }
      expect(find.text(BetaTestScriptCopy.failureHeading), findsOneWidget);
    });

    testWidgets('reset confirmation copy renders', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      await pumpScreen(tester);
      await openBetaTestScriptSheet(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('beta_test_script_reset_progress')),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(
        find.byKey(const Key('beta_test_script_reset_progress')),
      );
      await tester.pumpAndSettle();

      expect(find.text(BetaTestScriptCopy.resetTitle), findsOneWidget);
      expect(find.text(BetaTestScriptCopy.resetBody), findsOneWidget);
      expect(find.text(BetaTestScriptCopy.resetConfirmCta), findsOneWidget);
      expect(find.text(BetaTestScriptCopy.resetCancelCta), findsOneWidget);
    });
  });

  group('BetaTestScriptCard widget', () {
    testWidgets('renders compact card and view steps CTA', (tester) async {
      const card = BetaTestScriptCompactCard(
        title: BetaTestScriptCopy.compactTitle,
        body: BetaTestScriptCopy.compactBodyDay1,
        phase: BetaTestScriptCompactPhase.day1,
        showSendFeedbackSecondary: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BetaTestScriptCard(card: card, onViewSteps: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('beta_test_script_card')), findsOneWidget);
      expect(find.text(BetaTestScriptCopy.compactBodyDay1), findsOneWidget);
      expect(find.text(BetaTestScriptCopy.viewTestStepsCta), findsOneWidget);
    });
  });

  group('Analytics safety', () {
    test('metadata only without transcript phrase text', () {
      final captured = <({String event, Map<String, Object> props})>[];
      BetaTestScriptAnalytics.captureForTest = (event, props) =>
          captured.add((event: event, props: props));

      BetaTestScriptAnalytics.opened(
        source: 'testing_archiveme_screen',
        entryCount: 2,
      );
      BetaTestScriptAnalytics.stepSeen(
        source: 'testing_archiveme_screen',
        step: 'day_1',
        entryCount: 2,
      );
      BetaTestScriptAnalytics.feedbackCtaTapped(
        source: 'record',
        entryCount: 2,
      );

      expect(captured.map((e) => e.event), [
        BetaTestScriptAnalytics.openedEvent,
        BetaTestScriptAnalytics.stepSeenEvent,
        BetaTestScriptAnalytics.feedbackCtaTappedEvent,
      ]);
      for (final event in captured) {
        final blob = event.props.entries
            .map((e) => '${e.key}:${e.value}')
            .join(' ')
            .toLowerCase();
        expect(blob, isNot(contains('said yes')));
        expect(blob, isNot(contains('transcript')));
      }
    });
  });

  group('Protected areas', () {
    test(
      'beta test script files avoid billing signing and backend surfaces',
      () {
        const banned = [
          'RevenueCat',
          'Purchases.',
          'CFBundleVersion',
          'signing',
          'product_id',
          'api.archive',
        ];
        final files = [
          'lib/features/beta_test_script/beta_test_script_engine.dart',
          'lib/features/beta_test_script/beta_test_script_store.dart',
          'lib/widgets/account/beta_test_script_sheet.dart',
          'lib/widgets/record/beta_test_script_card.dart',
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
          expect(text.contains('journal.delete'), isFalse);
          expect(text.contains('deleteAll'), isFalse);
        }
      },
    );
  });
}
