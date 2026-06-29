import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/activation/second_session_payoff.dart';
import 'package:voicememory_mobile/features/activation/third_entry_belief_payoff.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/analysis_fallback_payoff.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/features/post_save/post_save_recorded_summary_copy.dart';
import 'package:voicememory_mobile/widgets/record/third_entry_belief_payoff_card.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
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

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript:
          '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      durationSeconds: 20,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _threeRepeatCapacityEntries() => [
      _voiceEntry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _voiceEntry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _voiceEntry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

const _bannedOneEntryWords = [
  'loop',
  'repeat',
  'repeating',
  'pattern found',
  'pressure loop',
  'form a belief',
];

const _bannedTwoEntryWords = [
  'form a belief',
  'pattern found',
];

const _bannedCertaintyWords = [
  'this means',
  'you always',
  'diagnosis',
  'therapy',
  'pattern found',
  'certain',
  'conclusion:',
];

List<String> _visibleText(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.isNotEmpty) texts.add(data);
  }
  return texts;
}

void _expectNoBannedCopy(Iterable<String> visible, List<String> banned) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in banned) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  group('ThirdEntryBeliefPayoffEngine', () {
    test('returns null unless exactly three eligible entries', () {
      expect(
        ThirdEntryBeliefPayoffEngine.build(
          entries: [
            _voiceEntry(
              id: 'e1',
              transcript: 'I felt pressure before saying yes again today.',
            ),
          ],
        ),
        isNull,
      );
      expect(
        ThirdEntryBeliefPayoffEngine.build(
          entries: [
            _voiceEntry(
              id: 'e1',
              transcript: 'I felt pressure before saying yes again today.',
            ),
            _voiceEntry(
              id: 'e2',
              transcript: 'My sister called about planning the weekend trip.',
            ),
          ],
        ),
        isNull,
      );
    });

    test('three usable entries shows cautious belief framing', () {
      final payoff = ThirdEntryBeliefPayoffEngine.build(
        entries: _threeRepeatCapacityEntries(),
      );

      expect(payoff, isNotNull);
      expect(payoff!.title, VisibleArchiveProofCopy.threeEntryBeliefTitle);
      expect(payoff.bodyIntro, contains('saved words suggest so far'));
      expect(payoff.bodySource, contains('saved words'));
      expect(payoff.evidenceRows.length, 3);
      expect(payoff.evidenceThin, isFalse);
      _expectNoBannedCopy(
        [payoff.title, payoff.bodyIntro, payoff.bodySource, ...payoff.evidenceRows],
        _bannedCertaintyWords,
      );
    });

    test('degraded entries do not count toward third-entry payoff', () {
      final payoff = ThirdEntryBeliefPayoffEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure before saying yes again even when I was tired.',
            createdAt: DateTime(2026, 6, 10, 12),
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Work kept pulling me back after I wanted to stop for the day.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _degradedVoiceEntry(id: 'e3'),
        ],
      );

      expect(payoff, isNull);
      expect(
        SecondSessionPayoffEngine.build(
          entries: [
            _voiceEntry(
              id: 'e1',
              transcript:
                  'I felt pressure before saying yes again even when I was tired.',
            ),
            _voiceEntry(
              id: 'e2',
              transcript:
                  'Work kept pulling me back after I wanted to stop for the day.',
            ),
          ],
        ),
        isNotNull,
      );
    });

    test('duplicate entries mark evidence as thin', () {
      const shared =
          'I had no capacity but I said yes again to the extra meeting today.';
      final payoff = ThirdEntryBeliefPayoffEngine.build(
        entries: [
          _voiceEntry(id: 'e1', transcript: shared, createdAt: DateTime(2026, 6, 10)),
          _voiceEntry(id: 'e2', transcript: shared, createdAt: DateTime(2026, 6, 11)),
          _voiceEntry(
            id: 'e3',
            transcript:
                'I said yes again even though I had no capacity for one more ask.',
            createdAt: DateTime(2026, 6, 12),
          ),
        ],
      );

      expect(payoff, isNotNull);
      expect(payoff!.evidenceThin, isTrue);
      expect(payoff.thinEvidenceNote, contains('distinct moment'));
      expect(payoff.thinEvidenceAction, contains('Add one more moment'));
    });

    test('analysis unavailable still allows local third-entry payoff', () {
      final payoff = ThirdEntryBeliefPayoffEngine.build(
        entries: _threeRepeatCapacityEntries(),
        analysisSucceeded: false,
      );

      expect(payoff, isNotNull);
      expect(payoff!.footnoteLine, contains('This moment is saved'));
      expect(
        AnalysisFallbackPayoffEngine.build(
          entries: _threeRepeatCapacityEntries(),
          analysisSucceeded: false,
        ),
        isNull,
      );
    });
  });

  group('ThirdEntryBeliefPayoffCard', () {
    testWidgets('renders belief title, body, evidence rows, and CTAs', (
      tester,
    ) async {
      const payoff = ThirdEntryBeliefPayoff(
        title: ThirdEntryBeliefPayoffCopy.title,
        bodyIntro: ThirdEntryBeliefPayoffCopy.bodyIntro,
        bodySource: ThirdEntryBeliefPayoffCopy.bodySource,
        evidenceRows: [
          'I felt pressure before saying yes again even when I was tired.',
          'Work kept pulling me back after I wanted to stop for the day.',
        ],
        evidenceThin: false,
        primaryCta: ThirdEntryBeliefPayoffCopy.primaryCta,
        secondaryCta: ThirdEntryBeliefPayoffCopy.secondaryCta,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ThirdEntryBeliefPayoffCard(
              payoff: payoff,
              onAddAnother: () {},
              onViewArchive: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('third_entry_belief_payoff_card')), findsOneWidget);
      expect(
        find.text('ArchiveMe is starting to form a belief.'),
        findsOneWidget,
      );
      expect(find.textContaining('saved words suggest so far'), findsOneWidget);
      expect(find.text(ThirdEntryBeliefPayoffCopy.bodySource), findsOneWidget);
      expect(find.text('Add one more moment'), findsOneWidget);
      expect(find.text('View archive'), findsOneWidget);
      expect(find.byKey(const Key('third_entry_belief_payoff_evidence_0')), findsOneWidget);
      _expectNoBannedCopy(_visibleText(tester), _bannedCertaintyWords);
    });
  });

  group('RecordScreen third-entry payoff', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_third_entry_belief_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpDoneState(
      WidgetTester tester, {
      required List<JournalEntry> entriesAfterSave,
      bool lastCaptureAnalysisSucceeded = true,
    }) async {
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: entriesAfterSave,
          lastCaptureAnalysisSucceeded: lastCaptureAnalysisSucceeded,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('one entry avoids belief repeat loop pattern language', (
      tester,
    ) async {
      await pumpDoneState(
        tester,
        entriesAfterSave: [
          _voiceEntry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
      );

      _expectNoBannedCopy(_visibleText(tester), _bannedOneEntryWords);
      expect(find.byKey(const Key('third_entry_belief_payoff_card')), findsNothing);
    });

    testWidgets('two entries stay focused without duplicate payoff cards', (
      tester,
    ) async {
      await pumpDoneState(
        tester,
        entriesAfterSave: [
          _voiceEntry(
            id: 'e1',
            transcript: 'A quiet moment about lunch with a friend today.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _voiceEntry(
            id: 'e2',
            transcript: 'Another unrelated note about errands this afternoon.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );

      expect(find.byKey(const Key('post_save_archive_home_nudge_card')), findsNothing);
      expect(find.byKey(const Key('third_entry_belief_payoff_card')), findsNothing);
      expect(find.byKey(const Key('post_save_focused_actions_bar')), findsOneWidget);
      expect(find.text(PostSaveRecordedSummaryCopy.title), findsOneWidget);
      _expectNoBannedCopy(_visibleText(tester), _bannedTwoEntryWords);
    });

    testWidgets('three repeated entries show one primary discovery result', (
      tester,
    ) async {
      await pumpDoneState(
        tester,
        entriesAfterSave: _threeRepeatCapacityEntries(),
      );

      expect(find.byKey(const Key('post_save_archive_home_nudge_card')), findsNothing);
      expect(find.byKey(const Key('third_entry_belief_payoff_card')), findsNothing);
      expect(find.text(PostSaveRecordedSummaryCopy.whatThisAddedTitle), findsOneWidget);
      expect(find.byKey(const Key('post_save_focused_actions_bar')), findsOneWidget);
      expect(find.byKey(const Key('analysis_fallback_payoff_card')), findsNothing);
      _expectNoBannedCopy(_visibleText(tester), _bannedCertaintyWords);
    });

    testWidgets('analysis unavailable still keeps focused post-save at third entry', (
      tester,
    ) async {
      await pumpDoneState(
        tester,
        entriesAfterSave: _threeRepeatCapacityEntries(),
        lastCaptureAnalysisSucceeded: false,
      );

      expect(find.byKey(const Key('post_save_archive_home_nudge_card')), findsNothing);
      expect(find.byKey(const Key('third_entry_belief_payoff_card')), findsNothing);
      expect(find.byKey(const Key('post_save_focused_actions_bar')), findsOneWidget);
      expect(find.byKey(const Key('analysis_fallback_payoff_card')), findsNothing);
    });
  });
}
