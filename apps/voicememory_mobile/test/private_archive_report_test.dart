import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_copy.dart';
import 'package:voicememory_mobile/features/early_archive/daily_return_reason_copy.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_copy.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_engine.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_gates.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_model.dart';
import 'package:voicememory_mobile/features/early_archive/weekly_archive_review_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/widgets/record/private_archive_report_card.dart';

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

List<JournalEntry> _fiveRelatedEntries() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'I said yes again even though I had no capacity for one more ask today.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
      _entry(
        id: 'e5',
        transcript:
            'Same yes pattern came back but it felt less urgent and easier to stop.',
        createdAt: DateTime(2026, 6, 14, 12),
      ),
    ];

RepeatReturnCheckRecord _answeredRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
}) =>
    RepeatReturnCheckRecord(
      entryId: entryId,
      choice: choice,
      entryCountAtCapture: 5,
      createdAt: DateTime(2026, 6, 14),
    );

void _expectNoDiagnosticLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
  expect(lower, isNot(contains('disorder')));
}

void main() {
  setUp(PrivateArchiveReportAnalytics.resetForTest);

  group('PrivateArchiveReportEngine', () {
    test('hidden without confirmed repeat evidence', () {
      expect(
        PrivateArchiveReportEngine.build(
          entries: [_entry(id: 'e1', transcript: 'A quiet day at home.')],
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });

    test('report includes repeat evidence phrases', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(report, isNotNull);
      final repeating = report!.sections.first;
      expect(repeating.heading, PrivateArchiveReportCopy.whatKeepsRepeatingHeading);
      expect(repeating.bullets, isNotEmpty);
      expect(
        report.fullPlainText,
        contains(repeating.bullets.first),
      );
    });

    test('report includes thought map sections', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final loop = report.sections[1];
      expect(loop.heading, PrivateArchiveReportCopy.loopHeading);
      expect(
        loop.lines.join('\n'),
        contains(ConfirmedRepeatThoughtMapCopy.triggerLabel),
      );
      expect(
        loop.lines.join('\n'),
        contains(ConfirmedRepeatThoughtMapCopy.thoughtLabel),
      );
    });

    test('report includes change proof when available', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _fiveRelatedEntries(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e5',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final changed = report.sections[2];
      expect(changed.heading, PrivateArchiveReportCopy.whatChangedHeading);
      expect(changed.lines, contains(RepeatReturnCheckCopy.changeProofTitle));
      expect(
        changed.lines,
        contains(RepeatReturnCheckCopy.trendSofterThanBefore),
      );
    });

    test('report includes positive pattern when available', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _mixedRepeatAndWalkEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final helped = report.sections[3];
      expect(helped.heading, PrivateArchiveReportCopy.whatHelpedHeading);
      expect(helped.bullets, isNotEmpty);
      expect(
        helped.bullets.join(' ').toLowerCase(),
        contains('walked outside'),
      );
    });

    test('report includes weekly review when available', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _fiveRelatedEntries(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e5',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final week = report.sections[4];
      expect(week.heading, PrivateArchiveReportCopy.thisWeekHeading);
      expect(week.lines, contains(WeeklyArchiveWeekReviewCopy.title));
      expect(
        week.lines.join('\n'),
        contains(WeeklyArchiveWeekReviewCopy.repeatedLabel),
      );
    });

    test('report includes next prompt', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final next = report.sections.last;
      expect(next.heading, PrivateArchiveReportCopy.recordNextHeading);
      expect(next.lines, contains(DailyReturnReasonCopy.title));
      expect(next.lines.any((line) => line.trim().isNotEmpty), isTrue);
    });

    test('no full transcript dump', () {
      final entries = _threeRelatedRepeatEntries();
      final report = PrivateArchiveReportEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final fullTranscript = entries.map((e) => e.transcript).join(' ');
      expect(report.fullPlainText, isNot(contains(fullTranscript)));
      for (final entry in entries) {
        if (entry.transcript.length > 48) {
          expect(report.fullPlainText, isNot(contains(entry.transcript)));
        }
      }
    });

    test('no therapy or diagnosis language in report copy', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _mixedRepeatAndWalkEntries(),
        returnChecks: [
          _answeredRecord(
            entryId: 'w5',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      _expectNoDiagnosticLanguage(report.fullPlainText);
      _expectNoDiagnosticLanguage(report.previewPlainText);
    });
  });

  group('PrivateArchiveReportGates', () {
    test('hidden during first-three activation', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(
        PrivateArchiveReportGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          viewingConfirmedRepeatOrTimeline: true,
          report: report,
        ),
        isTrue,
      );
      expect(PrivateArchiveReportGates.passesActivationGate(3), isFalse);
    });
  });

  group('PrivateArchiveReport preview/full boundary', () {
    test('free preview truncates sections and adds pro note', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _mixedRepeatAndWalkEntries(),
        returnChecks: [
          _answeredRecord(
            entryId: 'w5',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;

      final preview = report.plainText(isPro: false);
      expect(preview, contains(PrivateArchiveReportCopy.previewProNote));
      expect(preview, isNot(contains(PrivateArchiveReportCopy.thisWeekHeading)));
      expect(preview, isNot(contains(PrivateArchiveReportCopy.recordNextHeading)));

      final full = report.plainText(isPro: true);
      expect(full, isNot(contains(PrivateArchiveReportCopy.previewProNote)));
      expect(full, contains(PrivateArchiveReportCopy.thisWeekHeading));
      expect(full, contains(PrivateArchiveReportCopy.recordNextHeading));
    });
  });

  group('PrivateArchiveReportCard', () {
    testWidgets('copy action is wired safely', (tester) async {
      final report = PrivateArchiveReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      var copiedText = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrivateArchiveReportCard.test(
                report: report,
                entryCount: 3,
                surface: 'record',
                onCopy: (text) async {
                  copiedText = text;
                  return true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.ensureVisible(
        find.byKey(const Key('private_archive_report_copy_cta')),
      );
      await tester.tap(find.byKey(const Key('private_archive_report_copy_cta')));
      await tester.pump();

      expect(copiedText, contains(PrivateArchiveReportCopy.title));
      expect(copiedText, contains(PrivateArchiveReportCopy.whatKeepsRepeatingHeading));
    });
  });

  group('PrivateArchiveReportAnalytics', () {
    test('metadata only without transcript text', () {
      Map<String, Object>? captured;
      PrivateArchiveReportAnalytics.captureForTest = (event, props) {
        captured = props;
      };

      PrivateArchiveReportAnalytics.copyTapped(
        surface: 'record',
        entryCount: 5,
        isFullExport: false,
      );

      expect(captured, isNotNull);
      expect(
        captured!.keys,
        containsAll(['surface', 'entry_count', 'export_tier']),
      );
      expect(captured!.keys, isNot(contains('transcript')));
      expect(captured!['export_tier'], 'preview');
    });
  });
}
