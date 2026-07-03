import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/paywall_timing_gates.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/helpful_action_appeared_copy.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_copy.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_engine.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_gates.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_copy.dart';
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

List<JournalEntry> _fourRelatedRepeatEntries() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'I said yes again even though I had no capacity for one more ask today.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

List<JournalEntry> _fiveRelatedEntries() => [
      ..._fourRelatedRepeatEntries(),
      _entry(
        id: 'e5',
        transcript:
            'Same yes pattern came back but it felt less urgent and easier to stop.',
        createdAt: DateTime(2026, 6, 14, 12),
      ),
    ];

List<JournalEntry> _fourWithHelpfulAction() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'I paused before replying this time and it felt a bit softer.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

List<JournalEntry> _fourWithChangedReturn() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'I walked outside for five minutes before I replied to the message.',
        createdAt: DateTime(2026, 6, 13, 12),
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

void _expectNoAdviceLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('you should')));
  expect(lower, isNot(contains('try this')));
  expect(lower, isNot(contains('recommendations')));
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
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

    test('report sections render in exact order', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      expect(
        report.sections.map((section) => section.heading).toList(),
        [
          PrivateArchiveReportCopy.whatRepeatedHeading,
          PrivateArchiveReportCopy.whatSoftenedHeading,
          PrivateArchiveReportCopy.whatGotLouderHeading,
          PrivateArchiveReportCopy.whatHelpedHeading,
          PrivateArchiveReportCopy.whatChangedHeading,
          PrivateArchiveReportCopy.whatToRecordNextHeading,
        ],
      );
    });

    test('repeated phrase is grounded and max 6 words', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final repeated = report.sections.first;
      expect(repeated.hasEvidence, isTrue);
      final line = repeated.lines.first;
      expect(line, contains('showed up across'));
      final match = RegExp(r'"([^"]+)"').firstMatch(line);
      expect(match, isNotNull);
      final words = match!.group(1)!.trim().split(RegExp(r'\s+'));
      expect(words.length, lessThanOrEqualTo(6));
    });

    test('missing evidence shows fallback', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      expect(
        report.sections[1].lines.first,
        PrivateArchiveReportCopy.missingEvidenceFallback,
      );
      expect(
        report.sections[2].lines.first,
        PrivateArchiveReportCopy.missingEvidenceFallback,
      );
    });

    test('softened section uses softer evidence', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _fiveRelatedEntries(),
        returnChecks: [
          _answeredRecord(entryId: 'e5', choice: RepeatReturnCheckChoice.softer),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final softened = report.sections[1];
      expect(softened.lines.first, startsWith('This looked softer than before:'));
      expect(softened.hasEvidence, isTrue);
    });

    test('got louder section uses stronger evidence', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _fiveRelatedEntries(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e5',
            choice: RepeatReturnCheckChoice.stronger,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final louder = report.sections[2];
      expect(louder.lines.first, startsWith('This looked stronger than before:'));
      expect(louder.hasEvidence, isTrue);
    });

    test('helped section uses HelpfulActionAppeared evidence', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _fourWithHelpfulAction(),
        returnChecks: [
          _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final helped = report.sections[3];
      expect(helped.lines.first, startsWith('A helpful action appeared:'));
      expect(
        helped.lines.first.toLowerCase(),
        contains('paused before'),
      );
    });

    test('changed section uses PatternChanged evidence', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _fourWithChangedReturn(),
        returnChecks: [
          _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.changed),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final changed = report.sections[4];
      expect(
        changed.lines.first,
        startsWith('Something looked different this time:'),
      );
      expect(changed.hasEvidence, isTrue);
    });

    test('what-to-record-next section appears', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final next = report.sections.last;
      expect(next.heading, PrivateArchiveReportCopy.whatToRecordNextHeading);
      expect(next.lines.first, PrivateArchiveReportCopy.whatToRecordNextBody);
      expect(next.hasEvidence, isTrue);
    });

    test('no full transcript dump', () {
      final entries = _threeRelatedRepeatEntries();
      final report = PrivateArchiveReportEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      for (final entry in entries) {
        if (entry.transcript.length > 48) {
          expect(report.fullPlainText, isNot(contains(entry.transcript)));
        }
      }
    });

    test('no advice or coaching language', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _fourWithHelpfulAction(),
        returnChecks: [
          _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      _expectNoAdviceLanguage(report.fullPlainText);
      _expectNoAdviceLanguage(report.previewPlainText);
      expect(
        report.fullPlainText.toLowerCase(),
        isNot(contains('recommendations')),
      );
    });
  });

  group('PrivateArchiveReportGates', () {
    test('hidden during first-three activation for full history', () {
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
    test('free preview shows first section only and pro framing', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _fourWithHelpfulAction(),
        returnChecks: [
          _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;

      final preview = report.plainText(isPro: false);
      expect(preview, contains(PrivateArchiveReportCopy.previewTitle));
      expect(preview, contains(PrivateArchiveReportCopy.previewBody));
      expect(preview, contains(PrivateArchiveReportCopy.whatRepeatedHeading));
      expect(preview, isNot(contains(PrivateArchiveReportCopy.whatSoftenedHeading)));
      expect(preview, isNot(contains(PrivateArchiveReportCopy.whatToRecordNextHeading)));

      final full = report.plainText(isPro: true);
      expect(full, isNot(contains(PrivateArchiveReportCopy.previewTitle)));
      expect(full, contains(PrivateArchiveReportCopy.whatSoftenedHeading));
      expect(full, contains(PrivateArchiveReportCopy.whatToRecordNextHeading));
    });

    test('preview explains full report without entitlement changes', () {
      expect(PrivateArchiveReportCopy.previewTitle, 'Preview private report');
      expect(
        PrivateArchiveReportCopy.exportIncludedItems,
        [
          PrivateArchiveReportCopy.whatRepeatedHeading,
          PrivateArchiveReportCopy.whatChangedHeading,
          PrivateArchiveReportCopy.whatHelpedHeading,
          PrivateArchiveReportCopy.whatToRecordNextHeading,
        ],
      );
      expect(
        PrivateArchiveReportCopy.exportNotIncludedItems,
        [
          'Audio',
          'Full raw transcripts',
          'Private settings data',
        ],
      );
      expect(
        PrivateArchiveReportCopy.previewBody.toLowerCase(),
        contains('your first repeat'),
      );
      expect(
        PrivateArchiveReportCopy.intro,
        'Your archive noticed these evidence patterns from your own words.',
      );
    });

    test('private report is evidence summary not coaching report', () {
      final joined = [
        PrivateArchiveReportCopy.intro,
        PrivateArchiveReportCopy.previewBody,
        PrivateArchiveReportCopy.whatHelpedHeading,
        PrivateArchiveReportCopy.whatToRecordNextBody,
      ].join(' ').toLowerCase();

      expect(joined, contains('your archive noticed'));
      expect(joined, contains('your own words'));
      expect(joined, isNot(contains('recommendations')));
      expect(joined, isNot(contains('you should')));
      expect(joined, isNot(contains('try this')));
    });
  });

  group('PrivateArchiveReportCard', () {
    testWidgets('copy private report CTA and helper appear', (tester) async {
      final report = PrivateArchiveReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrivateArchiveReportCard.test(
                report: report,
                entryCount: 3,
                surface: 'patterns',
              ),
            ),
          ),
        ),
      );

      expect(
        find.text(PrivateArchiveReportCopy.copyReportCta),
        findsOneWidget,
      );
      expect(
        find.text(PrivateArchiveReportCopy.copyReportHelper),
        findsOneWidget,
      );
      expect(
        PrivateArchiveReportCopy.copyReportHelper,
        'Only report text is copied — not audio.',
      );
    });

    testWidgets('export scope lists included and not included sections', (
      tester,
    ) async {
      final report = PrivateArchiveReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrivateArchiveReportCard.test(
                report: report,
                entryCount: 3,
                surface: 'patterns',
                isPro: true,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('private_archive_report_export_included')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('private_archive_report_export_not_included')),
        findsOneWidget,
      );
      for (final item in PrivateArchiveReportCopy.exportIncludedItems) {
        expect(find.text('- $item'), findsOneWidget);
      }
      for (final item in PrivateArchiveReportCopy.exportNotIncludedItems) {
        expect(find.text('- $item'), findsOneWidget);
      }
    });

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
      expect(copiedText, contains(PrivateArchiveReportCopy.whatRepeatedHeading));
      expect(copiedText.toLowerCase(), isNot(contains('full raw transcripts')));
    });

    testWidgets('pro full export still includes all report sections', (
      tester,
    ) async {
      final report = PrivateArchiveReportEngine.build(
        entries: _fourWithHelpfulAction(),
        returnChecks: [
          _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      var copiedText = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrivateArchiveReportCard.test(
                report: report,
                entryCount: 4,
                surface: 'patterns',
                isPro: true,
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

      expect(copiedText, contains(PrivateArchiveReportCopy.whatSoftenedHeading));
      expect(
        copiedText,
        contains(PrivateArchiveReportCopy.whatToRecordNextHeading),
      );
      expect(copiedText, isNot(contains(PrivateArchiveReportCopy.previewTitle)));
    });

    testWidgets('free preview shows See Pro without full report sections', (
      tester,
    ) async {
      final report = PrivateArchiveReportEngine.build(
        entries: _fourWithHelpfulAction(),
        returnChecks: [
          _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrivateArchiveReportCard.test(
                report: report,
                entryCount: 4,
                surface: 'patterns',
                onSeePro: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        find.text(PrivateArchiveReportCopy.previewTitle),
        findsOneWidget,
      );
      expect(find.text(PrivateArchiveReportCopy.previewProCta), findsOneWidget);
      expect(
        find.text(PrivateArchiveReportCopy.whatToRecordNextHeading),
        findsNothing,
      );
    });
  });

  group('Private archive report Pro boundary', () {
    test('preview qualifies Pro boundary after entry 3', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(report, isNotNull);
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
      expect(PrivateArchiveReportGates.showPreviewNote(isPro: false), isTrue);
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 3,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: false,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
          hasPrivateArchiveReportPreview: true,
        ),
        isTrue,
      );
    });

    test('free confirmed repeat proof remains available without Pro', () {
      expect(
        EarlyFirstSignalEngine.build(entries: _threeRelatedRepeatEntries())
            ?.showsConfirmedRepeat,
        isTrue,
      );
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

  group('Copy distinct from other proof surfaces', () {
    test('report title distinct from pattern changed and helpful action', () {
      expect(PrivateArchiveReportCopy.title, isNot(PatternChangedCopy.title));
      expect(
        PrivateArchiveReportCopy.title,
        isNot(HelpfulActionAppearedCopy.title),
      );
    });
  });
}
