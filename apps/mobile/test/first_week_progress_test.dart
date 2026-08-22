import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:archiveme_mobile/features/retention/first_week_progress_copy.dart';
import 'package:archiveme_mobile/features/retention/first_week_progress_engine.dart';
import 'package:archiveme_mobile/features/retention/first_week_progress_model.dart';
import 'package:archiveme_mobile/features/retention/return_tomorrow_cue_engine.dart';
import 'package:archiveme_mobile/features/return_day/return_day_flow_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/widgets/record/first_week_progress_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _genericTest = 'This is a test to check function';
const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry(String id, String transcript, {DateTime? createdAt}) =>
    JournalEntry(
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

JournalEntry _voiceEntry({
  required String id,
  String transcript = '',
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
  transcript: transcript,
  durationSeconds: 24,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _threeRelatedEntries({DateTime? lastCreatedAt}) => [
  _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 10, 12)),
  _entry(
    '2',
    'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    '3',
    'I said yes again even though I had no capacity for one more ask.',
    createdAt: lastCreatedAt ?? DateTime(2026, 6, 12, 12),
  ),
];

void main() {
  tearDown(ActivationFunnelAnalytics.resetForTest);

  group('FirstWeekProgressEngine post-save', () {
    test(
      'shows day 1 after first real moment only when more than one entry',
      () {
        final now = DateTime(2026, 6, 12, 14);
        final oneEntryProgress = FirstWeekProgressEngine.buildPostSave(
          entries: [_entry('1', _strongRepeat, createdAt: now)],
          firstProofUnlocked: false,
          now: now,
        );
        expect(oneEntryProgress, isNull);

        final twoEntryProgress = FirstWeekProgressEngine.buildPostSave(
          entries: [
            _entry('1', _strongRepeat, createdAt: now),
            _entry(
              '2',
              'Another saved moment with enough words for archive evidence.',
              createdAt: now,
            ),
          ],
          firstProofUnlocked: false,
          now: now,
        );

        expect(twoEntryProgress, isNotNull);
        expect(twoEntryProgress!.state, FirstWeekProgressState.day1);
        expect(twoEntryProgress.title, FirstWeekProgressCopy.day1Title);
        expect(twoEntryProgress.body, FirstWeekProgressCopy.day1Body);
      },
    );

    test('first proof state replaces generic progress', () {
      final now = DateTime(2026, 6, 12, 14);
      final entries = _threeRelatedEntries(lastCreatedAt: now);
      final progress = FirstWeekProgressEngine.buildPostSave(
        entries: entries,
        firstProofUnlocked: true,
        now: now,
      );

      expect(progress, isNotNull);
      expect(progress!.state, FirstWeekProgressState.firstProof);
      expect(progress.title, FirstWeekProgressCopy.firstProofTitle);
      expect(progress.body, FirstWeekProgressCopy.firstProofBody);
      expect(FirstProofMomentEngine.build(entries: entries), isNotNull);
      expect(progress.title, isNot(contains('Day 1')));
    });
  });

  group('FirstWeekProgressEngine ready', () {
    test('shows day 2 on next day', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final progress = FirstWeekProgressEngine.buildReady(
        entries: [_entry('1', _strongRepeat, createdAt: yesterday)],
        now: now,
      );

      expect(progress, isNotNull);
      expect(progress!.state, FirstWeekProgressState.day2);
      expect(progress.title, FirstWeekProgressCopy.day2Title);
      expect(progress.body, FirstWeekProgressCopy.day2Body);
    });

    test('day 3–7 uses sharper copy', () {
      final now = DateTime(2026, 6, 14, 12);
      final progress = FirstWeekProgressEngine.buildReady(
        entries: [
          _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 10, 12)),
          _entry(
            '2',
            'Another saved moment with enough words for archive evidence.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
        ],
        now: now,
      );

      expect(progress, isNotNull);
      expect(progress!.state, FirstWeekProgressState.day3to7);
      expect(progress.title, FirstWeekProgressCopy.dayNTitle(5));
      expect(progress.body, FirstWeekProgressCopy.day3to7Body);
    });
  });

  group('FirstWeekProgressEngine evidence gates', () {
    test('no progress for generic test text', () {
      final entries = [_entry('1', _genericTest)];
      expect(
        ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries),
        isTrue,
      );
      expect(
        FirstWeekProgressEngine.buildPostSave(
          entries: entries,
          firstProofUnlocked: false,
        ),
        isNull,
      );
      expect(FirstWeekProgressEngine.buildReady(entries: entries), isNull);
    });

    test('no progress for placeholder', () {
      expect(
        FirstWeekProgressEngine.buildPostSave(
          entries: [_voiceEntry(id: 'p', transcript: _placeholder)],
          firstProofUnlocked: false,
        ),
        isNull,
      );
    });

    test('no progress for pending transcript', () {
      expect(
        FirstWeekProgressEngine.buildPostSave(
          entries: [_voiceEntry(id: 'p')],
          firstProofUnlocked: false,
        ),
        isNull,
      );
    });

    test('no progress for weak evidence', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final weak = _entry('1', 'ok', createdAt: yesterday);
      expect(
        ArchiveEvidenceQuality.assess(weak).level,
        ArchiveEvidenceQualityLevel.weak,
      );
      expect(FirstWeekProgressEngine.buildReady(entries: [weak]), isNull);
    });

    test('no progress after first week window', () {
      final now = DateTime(2026, 6, 20, 12);
      expect(
        FirstWeekProgressEngine.buildReady(
          entries: [
            _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 10, 12)),
          ],
          now: now,
        ),
        isNull,
      );
    });
  });

  group('FirstWeekProgressGates dedup', () {
    test('does not show with Return Day Flow on ready', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final entries = [_entry('1', _strongRepeat, createdAt: yesterday)];
      final progress = FirstWeekProgressEngine.buildReady(
        entries: entries,
        now: now,
      );
      final flow = ReturnDayFlowEngine.build(entries: entries, now: now);

      expect(progress, isNotNull);
      expect(flow, isNotNull);
      expect(
        FirstWeekProgressGates.shouldShowReady(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          progress: progress,
          showReturnDayFlow: true,
          showReturnTomorrowCue: false,
        ),
        isFalse,
      );
    });

    test('does not show with Return Tomorrow Cue on ready', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final entries = [_entry('1', _strongRepeat, createdAt: yesterday)];
      final progress = FirstWeekProgressEngine.buildReady(
        entries: entries,
        now: now,
      );
      final returnCue = ReturnTomorrowCueEngine.buildReady(
        entries: entries,
        now: now,
      );

      expect(progress, isNotNull);
      expect(returnCue, isNotNull);
      expect(
        FirstWeekProgressGates.shouldShowReady(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          progress: progress,
          showReturnDayFlow: false,
          showReturnTomorrowCue: true,
        ),
        isFalse,
      );
    });

    test('does not show with Return Tomorrow Cue on post-save', () {
      const progress = FirstWeekProgress(
        state: FirstWeekProgressState.day2,
        title: FirstWeekProgressCopy.day2Title,
        body: FirstWeekProgressCopy.day2Body,
        weekDay: 2,
      );

      expect(
        FirstWeekProgressGates.shouldShowPostSave(
          isPostSaveDone: true,
          isDegradedPostSave: false,
          progress: progress,
          showReturnTomorrowCue: true,
        ),
        isFalse,
      );
    });
  });

  group('FirstWeekProgressLine', () {
    testWidgets('Record CTA is not duplicated inside line', (tester) async {
      const progress = FirstWeekProgress(
        state: FirstWeekProgressState.day1,
        title: FirstWeekProgressCopy.day1Title,
        body: FirstWeekProgressCopy.day1Body,
        weekDay: 1,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FirstWeekProgressLine(progress: progress, entryCount: 1),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
    });

    test('copy avoids streak and shame language', () {
      final blob = FirstWeekProgressCopy.all.join(' ').toLowerCase();
      for (final banned in [
        'streak',
        'missed',
        'you should',
        "don't break",
        'keep your',
      ]) {
        expect(blob, isNot(contains(banned)), reason: banned);
      }
    });
  });
}