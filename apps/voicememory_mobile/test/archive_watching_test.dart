import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/archive_summary_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_summary_engine.dart';
import 'package:voicememory_mobile/features/early_archive/archive_watching_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_watching_engine.dart';
import 'package:voicememory_mobile/features/early_archive/archive_watching_gates.dart';
import 'package:voicememory_mobile/features/early_archive/daily_return_reason_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';
import 'package:voicememory_mobile/widgets/record/archive_summary_card.dart';
import 'package:voicememory_mobile/widgets/record/archive_watching_micro_state.dart';

JournalEntry _entry({
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

List<JournalEntry> _mixedRepeatAndWalkEntries() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'w4',
        transcript: 'I walked outside before replying and it helped.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
      _entry(
        id: 'w5',
        transcript: 'Same week I walked outside again before the hard email.',
        createdAt: DateTime(2026, 6, 14, 12),
      ),
    ];

RepeatReturnCheckChangeProof _changeProof(RepeatReturnCheckChoice choice) =>
    RepeatReturnCheckChangeProof(
      title: RepeatReturnCheckCopy.changeProofTitle,
      body: switch (choice) {
        RepeatReturnCheckChoice.stronger =>
          RepeatReturnCheckCopy.trendGettingLouder,
        RepeatReturnCheckChoice.softer =>
          RepeatReturnCheckCopy.trendSofterThanBefore,
        RepeatReturnCheckChoice.same => RepeatReturnCheckCopy.trendSteady,
      },
      latestChoice: choice,
    );

void _expectNoDiagnosticLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
  expect(lower, isNot(contains('disorder')));
}

void main() {
  group('ArchiveWatchingGates', () {
    test('hidden before 3 entries', () {
      expect(
        ArchiveWatchingGates.shouldShow(
          loaded: true,
          entryCount: 2,
          isReady: true,
          isRecording: false,
          viewingConfirmedRepeatOrTimeline: true,
          archiveSummaryVisible: true,
          hasWatching: true,
        ),
        isFalse,
      );
    });

    test('hidden without archive proof', () {
      expect(
        ArchiveWatchingGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          viewingConfirmedRepeatOrTimeline: false,
          archiveSummaryVisible: true,
          hasWatching: true,
        ),
        isFalse,
      );
    });

    test('hidden while recording', () {
      expect(
        ArchiveWatchingGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: true,
          viewingConfirmedRepeatOrTimeline: true,
          archiveSummaryVisible: true,
          hasWatching: true,
        ),
        isFalse,
      );
    });
  });

  group('ArchiveWatchingEngine', () {
    test('shows missing trigger watcher', () {
      final entries = _threeRelatedRepeatEntries();
      final watching = ArchiveWatchingEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(watching, isNotNull);
      expect(watching!.kind, ArchiveWatchingKind.missingTrigger);
      expect(
        watching.line,
        ArchiveWatchingCopy.gapLine(ArchiveWatchingCopy.missingTriggerFocus),
      );
    });

    test('shows change watcher', () {
      final entries = _threeRelatedRepeatEntries();
      final watching = ArchiveWatchingEngine.build(
        entries: entries,
        triggerCapturedMilestone: true,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(watching, isNotNull);
      expect(watching!.kind, ArchiveWatchingKind.missingChange);
      expect(
        watching.line,
        ArchiveWatchingCopy.gapLine(ArchiveWatchingCopy.missingChangeFocus),
      );
    });

    test('shows what helps watcher', () {
      final entries = _threeRelatedRepeatEntries();
      final watching = ArchiveWatchingEngine.build(
        entries: entries,
        triggerCapturedMilestone: true,
        changeProof: _changeProof(RepeatReturnCheckChoice.same),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(watching, isNotNull);
      expect(watching!.kind, ArchiveWatchingKind.missingPositive);
      expect(
        watching.line,
        ArchiveWatchingCopy.gapLine(ArchiveWatchingCopy.missingPositiveFocus),
      );
    });

    test('all known fallback', () {
      final watching = ArchiveWatchingEngine.build(
        entries: _mixedRepeatAndWalkEntries(),
        triggerCapturedMilestone: true,
        changeProof: _changeProof(RepeatReturnCheckChoice.softer),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(watching, isNotNull);
      expect(watching!.kind, ArchiveWatchingKind.allKnown);
      expect(watching.line, ArchiveWatchingCopy.allKnownLine);
    });
  });

  group('ArchiveWatchingCopy', () {
    test('safe language', () {
      final lines = [
        ArchiveWatchingCopy.prefix,
        ArchiveWatchingCopy.missingTriggerFocus,
        ArchiveWatchingCopy.missingChangeFocus,
        ArchiveWatchingCopy.missingPositiveFocus,
        ArchiveWatchingCopy.allKnownLine,
        ArchiveWatchingCopy.gapLine(ArchiveWatchingCopy.missingTriggerFocus),
      ];
      _expectNoDiagnosticLanguage(lines.join(' '));
      for (final line in lines) {
        for (final reason in PrivacyCopyPolicy.violationsInLiteral(line)) {
          fail('"$line": $reason');
        }
      }
    });
  });

  group('ArchiveWatchingMicroState', () {
    testWidgets('no duplicate CTA', (tester) async {
      final watching = ArchiveWatchingEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(watching, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveWatchingMicroState(watching: watching!),
          ),
        ),
      );

      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(DailyReturnReasonCopy.title), findsNothing);
      expect(find.text(DailyReturnReasonCopy.recordCta), findsNothing);
    });

    testWidgets('no transcript text', (tester) async {
      final entries = _threeRelatedRepeatEntries();
      final watching = ArchiveWatchingEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(watching, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveWatchingMicroState(watching: watching!),
          ),
        ),
      );

      expect(
        find.textContaining(entries.first.transcript),
        findsNothing,
      );
    });
  });

  group('ArchiveSummaryCard placement', () {
    testWidgets('renders watching micro-state inside summary card', (tester) async {
      final entries = _threeRelatedRepeatEntries();
      final summary = ArchiveSummaryEngine.build(
        entries: entries,
        confirmedRepeat: EarlyFirstSignalEngine.build(entries: entries),
        viewingConfirmedRepeatOrTimeline: true,
      );
      final watching = ArchiveWatchingEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(summary, isNotNull);
      expect(watching, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveSummaryCard(
                summary: summary!,
                showRecordNextCta: false,
                watching: watching,
              ),
            ),
          ),
        ),
      );

      expect(find.text(ArchiveSummaryCopy.title), findsOneWidget);
      expect(find.byKey(const Key('archive_watching_micro_state')), findsOneWidget);
      expect(find.text(watching!.line), findsOneWidget);
    });
  });
}
