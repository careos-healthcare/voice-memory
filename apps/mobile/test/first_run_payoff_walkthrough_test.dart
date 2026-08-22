import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/activation/archive_health_action_plan.dart';
import 'package:archiveme_mobile/features/activation/archive_health_score.dart';
import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_hints.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_layout.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_quick_actions.dart';
import 'package:archiveme_mobile/features/activation/context_insights.dart';
import 'package:archiveme_mobile/features/activation/evidence_attention_filters.dart';
import 'package:archiveme_mobile/features/activation/third_entry_belief_payoff.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/archive_tab/archive_tab_four_state_copy.dart';
import 'package:archiveme_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/record/record_screen_framing_copy.dart';
import 'package:archiveme_mobile/security/privacy_data_controls_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/capture_entry_actions.dart';
import 'package:archiveme_mobile/widgets/onboarding/first_save_evidence_card.dart';
import 'package:archiveme_mobile/widgets/record/record_first_run_privacy_reassurance.dart';
import 'package:archiveme_mobile/widgets/record/record_top_archive_promise_hero.dart';
import 'package:archiveme_mobile/widgets/settings/privacy_data_controls_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  String transcript =
      'I felt pressure at work before saying yes again even when I was tired.',
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
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

List<JournalEntry> _entries(int count) => List.generate(
  count,
  (i) => _entry(
    id: 'e$i',
    transcript:
        'I felt pressure at work before saying yes again even when I was tired moment $i.',
    createdAt: DateTime(2026, 6, 9 + i, 12),
  ),
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

ArchiveWorkspaceQuickActions _quickActions(List<JournalEntry> entries) {
  final archiveHome = ArchiveHomeSummaryEngine.build(entries: entries);
  final evidenceMap = ArchiveEvidenceMapEngine.build(entries: entries);
  final layout = _layout(entries);
  return ArchiveWorkspaceQuickActionsEngine.build(
    entries: entries,
    archiveHome: archiveHome,
    workspaceLayout: layout,
    evidenceMapVisible: evidenceMap.showCard,
    shareProof: const ShareableArchiveProofEngine().buildFromJournal(
      entries: entries,
    ),
  );
}

void main() {
  setUp(() async => ArchiveInsightFeedbackStore.resetForTest());

  group('0-entry Record first action', () {
    testWidgets('shows clear private archive promise', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Column(
              children: [
                RecordTopArchivePromiseHero(),
                RecordFirstRunPrivacyReassurance(),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(VisibleArchiveProofCopy.recordHeroTitle), findsNothing);
      for (final step in VisibleArchiveProofCopy.firstRunPromiseSteps) {
        expect(find.text(step), findsOneWidget);
      }
      expect(
        find.text(RecordScreenFramingCopy.firstRunPrivacyTitle),
        findsOneWidget,
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
      _expectNoBannedCopy(VisibleArchiveProofCopy.firstRunPromiseSteps);
    });

    testWidgets('Type Instead path is available without microphone', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: CaptureEntryActions(onRecord: () {})),
        ),
      );
      await tester.pump();

      expect(find.text(EmptyArchiveCopy.typeInsteadCta), findsOneWidget);
      expect(
        EmptyArchiveCopy.typeInsteadCta,
        MicrophonePermissionCopy.typeInsteadCta,
      );
      expect(
        MicrophonePermissionCopy.typeInsteadBlockedHelper,
        contains('no microphone'),
      );
    });
  });

  group('First saved entry payoff', () {
    testWidgets('first save card stays calm without overclaiming', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstSaveEvidenceCard(
              onViewArchive: () {},
              onRecordAnother: () {},
              onDoneForToday: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(RecordReturnProCopy.evidenceTitle),
        findsOneWidget,
      );
      expect(find.text(RecordReturnProCopy.evidenceBody), findsOneWidget);
      expect(
        find.text(RecordReturnProCopy.evidenceSecondLine),
        findsOneWidget,
      );
      expect(find.textContaining('Come back when this shows up again'), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
      _expectNoBannedCopy([
        RecordReturnProCopy.evidenceTitle,
        RecordReturnProCopy.evidenceBody,
        RecordReturnProCopy.evidenceSecondLine,
      ]);
    });
  });

  group('Archive/Patterns ladder', () {
    test('1-entry workspace is not noisy', () {
      final layout = _layout(_entries(1));
      final quickActions = _quickActions(_entries(1));
      final home = ArchiveHomeSummaryEngine.build(entries: _entries(1));

      expect(layout.stage, ArchiveWorkspaceStage.one);
      expect(layout.showActionPlan, isFalse);
      expect(layout.needsAttention.show, isFalse);
      expect(layout.evidenceQuality.show, isFalse);
      expect(quickActions.showCard, isFalse);
      expect(home.body, ArchiveTabFourStateCopy.oneBody);
      expect(home.primaryCta, isNull);
      expect(home.suppressDuplicatePayoffCards, isTrue);
    });

    test(
      '2-entry workspace shows comparison guidance without overclaiming',
      () {
        final home = ArchiveHomeSummaryEngine.build(entries: _entries(2));
        final quickActions = _quickActions(_entries(2));

        expect(home.stage, ArchiveHomeStage.two);
        expect(
          home.body,
          anyOf(
            ArchiveTabFourStateCopy.twoUnrelatedBody,
            contains('This may connect to:'),
          ),
        );
        expect(home.body.toLowerCase(), isNot(contains('pattern found')));
        expect(home.title, isEmpty);
        _expectNoBannedCopy([home.body]);
      },
    );

    test('3-entry state can show cautious belief payoff', () {
      final home = ArchiveHomeSummaryEngine.build(entries: _entries(3));
      final payoff = ThirdEntryBeliefPayoffEngine.build(entries: _entries(3));

      expect(home.stage, ArchiveHomeStage.three);
      expect(home.title, VisibleArchiveProofCopy.threeEntryBeliefTitle);
      expect(home.body.toLowerCase(), contains('saved words suggest so far'));
      expect(
        home.currentBeliefLine,
        VisibleArchiveProofCopy.threeEntryBeliefCurrentBeliefLine,
      );
      expect(payoff, isNotNull);
      _expectNoBannedCopy([
        home.title,
        home.body,
        home.currentBeliefLine!,
        payoff!.bodyIntro,
      ]);
    });
  });

  group('Settings privacy visibility', () {
    testWidgets('privacy and data controls section is visible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PrivacyDataControlsSection()),
        ),
      );
      await tester.pump();

      expect(find.text(PrivacyDataControlsCopy.sectionTitle), findsOneWidget);
      expect(
        find.byKey(const Key('privacy_data_stays_on_device_tile')),
        findsOneWidget,
      );
    });
  });

  group('First-run copy quality', () {
    test('no duplicate add-moment quick action at one entry', () {
      final quickActions = _quickActions(_entries(1));
      expect(quickActions.showCard, isFalse);
    });

    test('first-run copy uses ArchiveMe not VoiceMemory', () {
      const archiveMeStrings = [
        ArchiveTabFourStateCopy.oneBody,
        ConsumerUiCopy.patternsFirstEntrySavedBody,
        PrivacyDataControlsCopy.dataStaysOnDeviceBody,
        VisibleArchiveProofCopy.recordHeroTitle,
      ];
      for (final text in archiveMeStrings) {
        expect(text, contains('ArchiveMe'), reason: text);
        expect(
          text.toLowerCase(),
          isNot(contains('voicememory')),
          reason: text,
        );
      }
      expect(
        VisibleArchiveProofCopy.typeInsteadCta.toLowerCase(),
        isNot(contains('voicememory')),
      );
      _expectNoBannedCopy(archiveMeStrings);
    });

    test('0-entry hints stay calm', () {
      final hints = ArchiveWorkspaceHintsEngine.build(
        layout: _layout(const []),
      );
      expect(hints.introHint, isNotNull);
      expect(hints.needsAttentionHint, isNull);
    });
  });
}