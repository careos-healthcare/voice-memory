import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta/beta_metrics_decision_copy.dart';
import 'package:voicememory_mobile/features/beta/beta_metrics_decision_engine.dart';
import 'package:voicememory_mobile/features/beta/beta_release_qa_copy.dart';
import 'package:voicememory_mobile/features/beta/beta_release_qa_engine.dart';
import 'package:voicememory_mobile/features/beta/core_value_feedback_analytics.dart';
import 'package:voicememory_mobile/features/beta/core_value_feedback_copy.dart';
import 'package:voicememory_mobile/features/beta/core_value_feedback_gates.dart';
import 'package:voicememory_mobile/features/beta/core_value_feedback_model.dart';
import 'package:voicememory_mobile/features/beta/core_value_feedback_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/beta/core_value_feedback_card.dart';
import 'package:voicememory_mobile/widgets/debug/beta_metrics_decision_card.dart';
import 'package:voicememory_mobile/widgets/debug/beta_release_qa_card.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/core_value_feedback/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

JournalEntry _entry({required String id, String? transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 1, 12),
  transcript:
      transcript ??
      'A long enough transcript to count as a saved reflection for tests.',
  durationSeconds: 30,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'You mentioned pressure in this moment.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _relatedThree() => [
  _entry(
    id: 'e1',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
  ),
  _entry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
  ),
  _entry(
    id: 'e3',
    transcript:
        'Still agreed to one more thing even though I had no capacity left.',
  ),
];

void main() {
  tearDown(() async {
    ArchiveBetaMissionGate.resetForTest();
    ActivationFunnelAnalytics.resetForTest();
    DeveloperSettingsGate.resetForTest();
    await CoreValueFeedbackStore.resetForTest();
  });

  group('CoreValueFeedbackGates', () {
    test('hidden when beta/debug gate is false', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(
        CoreValueFeedbackGates.shouldShowOnRecordPostFirstProof(
          showFirstProofMoment: true,
          isPostSaveDone: true,
          entryCount: 3,
          hasConfirmedRepeatFoundation: true,
          isRecording: false,
          isDegradedPostSave: false,
          isProPaywallVisible: false,
        ),
        isFalse,
      );
    });

    test('hidden before first proof', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        CoreValueFeedbackGates.shouldShowOnRecordPostFirstProof(
          showFirstProofMoment: false,
          isPostSaveDone: true,
          entryCount: 2,
          hasConfirmedRepeatFoundation: false,
          isRecording: false,
          isDegradedPostSave: false,
          isProPaywallVisible: false,
        ),
        isFalse,
      );
    });

    test('hidden without confirmed repeat', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        CoreValueFeedbackGates.shouldShowOnRecordPostFirstProof(
          showFirstProofMoment: true,
          isPostSaveDone: true,
          entryCount: 3,
          hasConfirmedRepeatFoundation: false,
          isRecording: false,
          isDegradedPostSave: false,
          isProPaywallVisible: false,
        ),
        isFalse,
      );
    });

    test('shown after first proof when beta flag is true', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        CoreValueFeedbackGates.shouldShowOnRecordPostFirstProof(
          showFirstProofMoment: true,
          isPostSaveDone: true,
          entryCount: 3,
          hasConfirmedRepeatFoundation: true,
          isRecording: false,
          isDegradedPostSave: false,
          isProPaywallVisible: false,
        ),
        isTrue,
      );
    });

    test('shown on Patterns after ArchiveCurrentBelief when unanswered', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final entries = _relatedThree();
      expect(
        CoreValueFeedbackGates.shouldShowOnPatternsArchive(
          showArchiveCurrentBelief: true,
          archiveBeliefSurfaceVisible: true,
          entryCount: entries.length,
          entries: entries,
          isRecording: false,
          isProPaywallVisible: false,
        ),
        isTrue,
      );
    });

    test('hidden during entry 0-2', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        CoreValueFeedbackGates.shouldShowOnRecordPostFirstProof(
          showFirstProofMoment: true,
          isPostSaveDone: true,
          entryCount: 2,
          hasConfirmedRepeatFoundation: true,
          isRecording: false,
          isDegradedPostSave: false,
          isProPaywallVisible: false,
        ),
        isFalse,
      );
    });

    test('hidden when already answered', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        CoreValueFeedbackGates.shouldShowOnRecordPostFirstProof(
          showFirstProofMoment: true,
          isPostSaveDone: true,
          entryCount: 3,
          hasConfirmedRepeatFoundation: true,
          isRecording: false,
          isDegradedPostSave: false,
          isProPaywallVisible: false,
          record: const CoreValueFeedbackRecord(
            answer: CoreValueFeedbackAnswer.yes,
          ),
        ),
        isFalse,
      );
    });

    test('hidden when dismissed for session', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        CoreValueFeedbackGates.shouldShowOnRecordPostFirstProof(
          showFirstProofMoment: true,
          isPostSaveDone: true,
          entryCount: 3,
          hasConfirmedRepeatFoundation: true,
          isRecording: false,
          isDegradedPostSave: false,
          isProPaywallVisible: false,
          dismissed: true,
        ),
        isFalse,
      );
    });

    test('hidden on pro paywall bridge', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        CoreValueFeedbackGates.shouldShowOnPatternsArchive(
          showArchiveCurrentBelief: true,
          archiveBeliefSurfaceVisible: true,
          entryCount: 3,
          entries: _relatedThree(),
          isRecording: false,
          isProPaywallVisible: true,
        ),
        isFalse,
      );
    });
  });

  group('CoreValueFeedbackCopy', () {
    test('question copy matches exactly', () {
      expect(
        CoreValueFeedbackCopy.question,
        'Did ArchiveMe show something repeating in your own words that was worth tracking?',
      );
      expect(CoreValueFeedbackCopy.title, 'Beta feedback');
      expect(
        CoreValueFeedbackCopy.helper,
        'This is the main thing I’m testing.',
      );
      expect(
        CoreValueFeedbackCopy.savedMessage,
        'Beta feedback saved. Thank you.',
      );
      expect(CoreValueFeedbackCopy.answerYes, 'Yes');
      expect(CoreValueFeedbackCopy.answerNotYet, 'Not yet');
      expect(CoreValueFeedbackCopy.answerGeneric, 'Felt generic');
      expect(CoreValueFeedbackCopy.hideForNow, 'Hide for now');
    });
  });

  group('CoreValueFeedbackStore', () {
    late _MemoryPrefs prefs;
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_core_value_feedback_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
      prefs = _MemoryPrefs();
      await CoreValueFeedbackStore.resetForTest();
    });

    test('Yes answer persists locally', () async {
      final store = CoreValueFeedbackStore(prefs);
      await store.saveAnswer(
        answer: CoreValueFeedbackAnswer.yes,
        entryCount: 3,
        source: CoreValueFeedbackSource.recordPostFirstProof,
      );
      final loaded = await store.loadAnswer();
      expect(loaded.answer, CoreValueFeedbackAnswer.yes);
      expect(loaded.entryCount, 3);
      expect(loaded.source, CoreValueFeedbackSource.recordPostFirstProof);
      expect(loaded.timestamp, isNotNull);
    });

    test('Not yet answer persists locally', () async {
      final store = CoreValueFeedbackStore(prefs);
      await store.saveAnswer(
        answer: CoreValueFeedbackAnswer.notYet,
        entryCount: 4,
        source: CoreValueFeedbackSource.patternsArchive,
      );
      final loaded = await store.loadAnswer();
      expect(loaded.answer, CoreValueFeedbackAnswer.notYet);
      expect(loaded.source, CoreValueFeedbackSource.patternsArchive);
    });

    test('Felt generic answer persists locally', () async {
      final store = CoreValueFeedbackStore(prefs);
      await store.saveAnswer(
        answer: CoreValueFeedbackAnswer.generic,
        entryCount: 5,
        source: CoreValueFeedbackSource.patternsArchive,
      );
      final loaded = await store.loadAnswer();
      expect(loaded.answer, CoreValueFeedbackAnswer.generic);
    });

    test('dismiss hides prompt for session', () async {
      final store = CoreValueFeedbackStore(prefs);
      expect(CoreValueFeedbackStore.isDismissed, isFalse);
      store.dismissForSession();
      expect(CoreValueFeedbackStore.isDismissed, isTrue);
    });

    test('dismiss hides prompt for day', () async {
      final store = CoreValueFeedbackStore(prefs);
      await store.dismissForDay();
      expect(CoreValueFeedbackStore.isDismissed, isTrue);
    });
  });

  group('CoreValueFeedbackCard', () {
    testWidgets('renders exact copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoreValueFeedbackCard.test(
              source: CoreValueFeedbackSource.recordPostFirstProof,
              entryCount: 3,
              hasConfirmedRepeat: true,
              hasFirstProof: true,
            ),
          ),
        ),
      );

      expect(find.text(CoreValueFeedbackCopy.title), findsOneWidget);
      expect(find.text(CoreValueFeedbackCopy.question), findsOneWidget);
      expect(find.text(CoreValueFeedbackCopy.helper), findsOneWidget);
      expect(find.text(CoreValueFeedbackCopy.answerYes), findsOneWidget);
      expect(find.text(CoreValueFeedbackCopy.answerNotYet), findsOneWidget);
      expect(find.text(CoreValueFeedbackCopy.answerGeneric), findsOneWidget);
      expect(find.text(CoreValueFeedbackCopy.hideForNow), findsOneWidget);
    });

    testWidgets('answered state shows saved thank you', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoreValueFeedbackCard.test(
              source: CoreValueFeedbackSource.recordPostFirstProof,
              entryCount: 3,
              hasConfirmedRepeat: true,
              hasFirstProof: true,
              initialRecord: const CoreValueFeedbackRecord(
                answer: CoreValueFeedbackAnswer.yes,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('core_value_feedback_saved')),
        findsOneWidget,
      );
      expect(find.text(CoreValueFeedbackCopy.savedMessage), findsOneWidget);
      expect(find.text(CoreValueFeedbackCopy.question), findsNothing);
    });

    testWidgets('dismiss hides prompt for session', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoreValueFeedbackCard.test(
              source: CoreValueFeedbackSource.patternsArchive,
              entryCount: 3,
              hasConfirmedRepeat: true,
              hasFirstProof: true,
              dismissed: true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('core_value_feedback_hidden')),
        findsOneWidget,
      );
    });

    testWidgets('no duplicate primary CTA', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoreValueFeedbackCard.test(
              source: CoreValueFeedbackSource.recordPostFirstProof,
              entryCount: 3,
              hasConfirmedRepeat: true,
              hasFirstProof: true,
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('CoreValueFeedbackAnalytics', () {
    test('analytics excludes transcript phrase and user content', () {
      final events = <String, Map<String, Object>>{};
      ActivationFunnelAnalytics.captureForTest((event, props) {
        events[event] = props;
      });

      CoreValueFeedbackAnalytics.seen(
        entryCount: 3,
        source: CoreValueFeedbackSource.recordPostFirstProof,
        hasConfirmedRepeat: true,
        hasFirstProof: true,
      );
      CoreValueFeedbackAnalytics.answered(
        answer: CoreValueFeedbackAnswer.yes,
        entryCount: 3,
        source: CoreValueFeedbackSource.recordPostFirstProof,
        hasConfirmedRepeat: true,
        hasFirstProof: true,
      );
      CoreValueFeedbackAnalytics.dismissed(
        entryCount: 3,
        source: CoreValueFeedbackSource.patternsArchive,
        hasConfirmedRepeat: true,
        hasFirstProof: true,
      );

      expect(events.keys, contains(CoreValueFeedbackAnalytics.seenEvent));
      expect(events.keys, contains(CoreValueFeedbackAnalytics.answeredEvent));
      expect(events.keys, contains(CoreValueFeedbackAnalytics.dismissedEvent));

      for (final props in events.values) {
        final joined = props.entries
            .map((entry) => '${entry.key}:${entry.value}')
            .join(' ')
            .toLowerCase();
        expect(joined, isNot(contains('transcript')));
        expect(joined, isNot(contains('phrase')));
        expect(joined, isNot(contains('said yes')));
        expect(props.containsKey('answer') || props['source'] != null, isTrue);
        if (props.containsKey('answer')) {
          expect(props['answer'], isIn(['yes', 'not_yet', 'generic']));
        }
        expect(props['entry_count'], 3);
        expect(props['has_confirmed_repeat'], 1);
        expect(props['has_first_proof'], 1);
        expect(
          props['source'],
          isIn(['record_post_first_proof', 'patterns_archive']),
        );
      }
    });
  });

  group('Developer diagnostics', () {
    test('beta release QA surfaces answer state', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'vm_core_value_diag_',
      );
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
      final store = CoreValueFeedbackStore(_MemoryPrefs());
      await store.saveAnswer(
        answer: CoreValueFeedbackAnswer.generic,
        entryCount: 3,
        source: CoreValueFeedbackSource.recordPostFirstProof,
      );

      final report = BetaReleaseQaEngine.build();
      expect(
        report.coreValueFeedbackAnswer,
        CoreValueFeedbackCopy.answerGeneric,
      );
    });

    testWidgets('beta metrics decision card shows core value feedback', (
      tester,
    ) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);
      final store = CoreValueFeedbackStore(_MemoryPrefs());
      await store.saveAnswer(
        answer: CoreValueFeedbackAnswer.notYet,
        entryCount: 3,
        source: CoreValueFeedbackSource.patternsArchive,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BetaMetricsDecisionCard(
                report: BetaMetricsDecisionEngine.build(
                  input: BetaMetricsDecisionEngine.fromBetaCounts(),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.text(BetaMetricsDecisionCopy.coreValueFeedbackLabel),
        findsOneWidget,
      );
      expect(find.text(CoreValueFeedbackCopy.answerNotYet), findsOneWidget);
    });

    testWidgets('beta release QA card shows core value feedback', (
      tester,
    ) async {
      DeveloperSettingsGate.applyLoadedUnlock(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BetaReleaseQaCard(report: BetaReleaseQaEngine.build()),
            ),
          ),
        ),
      );

      expect(
        find.text(BetaReleaseQaCopy.coreValueFeedbackLabel),
        findsOneWidget,
      );
      expect(
        find.text(CoreValueFeedbackCopy.diagnosticsNoAnswer),
        findsOneWidget,
      );
    });
  });

  group('Production gate off', () {
    test('gates false when beta flag off', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(
        CoreValueFeedbackGates.shouldShowOnPatternsArchive(
          showArchiveCurrentBelief: true,
          archiveBeliefSurfaceVisible: true,
          entryCount: 3,
          entries: _relatedThree(),
          isRecording: false,
          isProPaywallVisible: false,
        ),
        isFalse,
      );
    });
  });
}
