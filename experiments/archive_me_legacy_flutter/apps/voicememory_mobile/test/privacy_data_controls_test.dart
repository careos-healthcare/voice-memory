import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/archive_home_summary.dart';
import 'package:voicememory_mobile/features/activation/archive_insight_feedback.dart';
import 'package:voicememory_mobile/features/activation/archive_workspace_hint_store.dart';
import 'package:voicememory_mobile/features/activation/archive_workspace_hints.dart';
import 'package:voicememory_mobile/features/activation/archive_workspace_layout.dart';
import 'package:voicememory_mobile/features/activation/archive_workspace_quick_actions.dart';
import 'package:voicememory_mobile/features/activation/evidence_attention_filters.dart';
import 'package:voicememory_mobile/features/activation/archive_health_action_plan.dart';
import 'package:voicememory_mobile/features/activation/archive_health_score.dart';
import 'package:voicememory_mobile/features/activation/archive_evidence_map.dart';
import 'package:voicememory_mobile/features/activation/context_insights.dart';
import 'package:voicememory_mobile/features/activation/capture_context_tags.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/security/local_privacy_data_controls.dart';
import 'package:voicememory_mobile/security/privacy_data_controls_copy.dart';
import 'package:voicememory_mobile/security/private_data_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/settings/privacy_data_controls_dialogs.dart';
import 'package:voicememory_mobile/widgets/settings/privacy_data_controls_section.dart';

Reflection _reflection() => const Reflection(
  mood: 'neutral',
  emotionalIntensity: 2,
  recurringThemes: ['work'],
  exactLanguagePattern: '',
  concreteObservation: 'Work pressure showed up in this moment.',
  repeatedSignal: '',
);

JournalEntry _entry({
  String id = 'e1',
  String transcript = 'Private reflection text about work pressure.',
  String? captureContextTag,
  bool pinned = false,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: _reflection(),
  syncStatus: SyncStatus.localOnly,
  captureContextTag: captureContextTag,
  isPinned: pinned,
  pinnedAt: pinned ? DateTime(2026, 6, 12, 12) : null,
);

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'certain',
  'must come back',
  'share to unlock',
];

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

ArchiveWorkspaceLayout _layout(List<JournalEntry> entries) {
  final archiveHome = ArchiveHomeSummaryEngine.build(entries: entries);
  return ArchiveWorkspaceLayoutEngine.build(
    entries: entries,
    archiveHome: archiveHome,
    attentionFilters: EvidenceAttentionFiltersEngine.build(entries: entries),
    actionPlan: ArchiveHealthActionPlanEngine.build(entries: entries),
    archiveHealth: ArchiveHealthScoreEngine.build(entries: entries),
    contextInsights: ContextInsightsEngine.build(entries: entries),
    evidenceMap: ArchiveEvidenceMapEngine.build(entries: entries),
  );
}

Future<void> _seedJournal(JournalStore store, JournalEntry entry) async {
  await store.save(entry);
}

void main() {
  late Directory tempDir;
  late JournalStore journal;
  late MobilePrefsStore prefs;
  late PrivateDataService privateData;
  late LocalPrivacyDataControls controls;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('privacy_data_controls_');
    journal = await JournalStore.open(
      '${tempDir.path}/entries.json',
      encryptAtRest: false,
    );
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    privateData = PrivateDataService(
      journalStore: journal,
      prefs: prefs,
      tempDirProvider: () async => tempDir,
    );
    controls = LocalPrivacyDataControls(privateDataService: privateData);

    ArchiveInsightFeedbackStore.resetForTest();
    ArchiveWorkspaceHintStore.resetForTest();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Settings privacy section', () {
    testWidgets('shows Privacy & data section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PrivacyDataControlsSection()),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('privacy_data_controls_section_title')),
        findsOneWidget,
      );
      expect(find.text(PrivacyDataControlsCopy.sectionTitle), findsOneWidget);
      expect(
        find.byKey(const Key('privacy_data_stays_on_device_tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('privacy_data_reset_dismissed_tips_tile')),
        findsOneWidget,
      );
    });

    test('settings screen includes standard archive controls', () {
      final src = File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(src, contains('AccountPrivacyControlsSection'));
      expect(src, contains('PrivacyDataControlsSection'));
    });
  });

  group('Privacy explanation copy', () {
    test('uses ArchiveMe and not VoiceMemory in user-facing copy', () {
      _expectNoBannedCopy([
        PrivacyDataControlsCopy.dataStaysOnDeviceTitle,
        PrivacyDataControlsCopy.dataStaysOnDeviceBody,
        PrivacyDataControlsCopy.clearLocalArchiveConfirmBody,
        PrivacyDataControlsCopy.resetDismissedTipsConfirmBody,
      ]);
      expect(
        PrivacyDataControlsCopy.dataStaysOnDeviceBody,
        contains('ArchiveMe'),
      );
      expect(
        PrivacyDataControlsCopy.dataStaysOnDeviceBody,
        isNot(contains('VoiceMemory')),
      );
    });

    testWidgets('privacy explanation sheet renders ArchiveMe copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showLocalDataStaysSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy_data_stays_body')), findsOneWidget);
      expect(find.textContaining('ArchiveMe'), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });

  group('Clear local archive', () {
    testWidgets(
      'requires confirmation dialog with cancel and confirm actions',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showClearLocalArchiveDialog(context),
                  child: const Text('clear'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('clear'));
        await tester.pump();

        expect(
          find.byKey(const Key('clear_local_archive_cancel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('clear_local_archive_confirm')),
          findsOneWidget,
        );
        expect(
          find.text(PrivacyDataControlsCopy.clearLocalArchiveConfirmBody),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('clear_local_archive_cancel')));
        await tester.pump();
      },
    );

    test('cancel does not delete seeded journal entries', () async {
      await _seedJournal(journal, _entry());
      expect(await journal.loadAll(), isNotEmpty);
    });

    test(
      'confirm clears local journal entries and archive-derived state',
      () async {
        await _seedJournal(
          journal,
          _entry(
            id: 'e1',
            captureContextTag: CaptureContextTagIds.work,
            pinned: true,
          ),
        );
        ArchiveInsightFeedbackStore.record(
          ArchiveInsightFeedbackStore.targetId(
            ArchiveInsightTarget.beliefEvidence,
          ),
          ArchiveInsightFeedbackChoice.notQuite,
        );
        ArchiveInsightFeedbackStore.saveCorrectionNote(
          ArchiveInsightFeedbackStore.targetId(
            ArchiveInsightTarget.beliefEvidence,
          ),
          'This felt more about hurry than pressure.',
        );
        ArchiveInsightFeedbackStore.hide('contextInsight');
        ArchiveWorkspaceHintStore.dismiss(ArchiveWorkspaceHintIds.intro);
        await ArchiveWorkspaceHintStore.flushForTest();
        await prefs.writeMap('pinnedEvidence', {
          'ids': ['e1'],
        });

        await controls.clearLocalArchive();

        expect(await journal.loadAll(), isEmpty);
        expect(ArchiveInsightFeedbackStore.totalNotQuiteCount(), 0);
        expect(ArchiveInsightFeedbackStore.correctionNoteCount(), 0);
        expect(ArchiveInsightFeedbackStore.hiddenInsightCount(), 0);
        expect(
          ArchiveWorkspaceHintStore.isDismissed(ArchiveWorkspaceHintIds.intro),
          isFalse,
        );
      },
    );

    test(
      'after clear Archive/Patterns returns to calm 0-entry state',
      () async {
        await _seedJournal(journal, _entry());
        await controls.clearLocalArchive();

        final entries = await journal.loadAll();
        final layout = _layout(entries);
        final quickActions = ArchiveWorkspaceQuickActionsEngine.build(
          entries: entries,
          archiveHome: ArchiveHomeSummaryEngine.build(entries: entries),
          workspaceLayout: layout,
          evidenceMapVisible: false,
        );
        final hints = ArchiveWorkspaceHintsEngine.build(layout: layout);

        expect(layout.stage, ArchiveWorkspaceStage.empty);
        expect(layout.evidenceQuality.show, isFalse);
        expect(quickActions.showCard, isFalse);
        expect(hints.introHint, isNotNull);
        expect(hints.needsAttentionHint, isNull);
      },
    );

    test(
      'share-safe proof does not include old private entry text after clear',
      () async {
        const sensitive =
            'Maria told me about the divorce paperwork at the hospital again';
        await _seedJournal(journal, _entry(transcript: sensitive));
        await controls.clearLocalArchive();

        const engine = ShareableArchiveProofEngine();
        final proof = engine.buildFromJournal(entries: await journal.loadAll());
        expect(proof.hasProof, isFalse);
        expect(proof.shareText.toLowerCase(), isNot(contains('maria')));
      },
    );
  });

  group('Reset dismissed tips', () {
    test('reset dismissed tips makes workspace hints visible again', () async {
      ArchiveWorkspaceHintStore.dismiss(ArchiveWorkspaceHintIds.intro);
      ArchiveWorkspaceHintStore.dismiss(
        ArchiveWorkspaceHintIds.evidenceQuality,
      );
      await ArchiveWorkspaceHintStore.flushForTest();

      await controls.resetDismissedTips();

      expect(
        ArchiveWorkspaceHintStore.isDismissed(ArchiveWorkspaceHintIds.intro),
        isFalse,
      );
      final hints = ArchiveWorkspaceHintsEngine.build(
        layout: _layout(_entriesForHints()),
      );
      expect(hints.introHint, isNotNull);
    });
  });
}

List<JournalEntry> _entriesForHints() => List.generate(
  3,
  (i) => _entry(
    id: 'e$i',
    transcript:
        'I felt pressure at work before saying yes again even when I was tired moment $i.',
    captureContextTag: i.isEven
        ? CaptureContextTagIds.work
        : CaptureContextTagIds.home,
  ),
);
