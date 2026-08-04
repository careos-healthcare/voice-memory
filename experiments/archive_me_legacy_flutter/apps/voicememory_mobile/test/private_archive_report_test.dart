import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/paywall_timing_gates.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_copy.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_engine.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_gates.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_model.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:voicememory_mobile/features/private_report/private_report_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_copy.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/record/private_archive_report_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
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

RepeatReturnCheckRecord _answeredRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
}) => RepeatReturnCheckRecord(
  entryId: entryId,
  choice: choice,
  entryCountAtCapture: 5,
  createdAt: DateTime(2026, 6, 14),
);

void _expectNoAdviceLanguage(String copy) {
  final lower = copy.replaceAll(PrivateReportCopy.footer, '').toLowerCase();
  expect(lower, isNot(contains('you should')));
  expect(lower, isNot(contains('try this')));
  expect(lower, isNot(contains('recommendations')));
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
}

void main() {
  setUp(() async {
    PrivateArchiveReportAnalytics.resetForTest();
    await WhatChangedV2Store.resetForTest();
    await HelpedTrackingStore.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() async {
    await WhatChangedV2Store.resetForTest();
    await HelpedTrackingStore.resetForTest();
  });

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
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      expect(report.sections.map((section) => section.heading).toList(), [
        PrivateArchiveReportCopy.whatRepeatedHeading,
        PrivateArchiveReportCopy.whatChangedHeading,
        PrivateArchiveReportCopy.whatHelpedHeading,
        PrivateArchiveReportCopy.evidenceHeading,
        PrivateArchiveReportCopy.whatToWatchNextHeading,
      ]);
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

    test('changed section uses WhatChanged v2 marker', () async {
      final store = WhatChangedV2Store.instance();
      await store.saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.softer,
        entryCountAtCapture: 4,
      );

      final report = PrivateArchiveReportEngine.build(
        entries: _fourRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final changed = report.sections[1];
      expect(changed.hasEvidence, isTrue);
      expect(changed.lines.first, WhatChangedV2Copy.payoffSofter);
    });

    test('helped section uses helped tracking marker', () async {
      final store = HelpedTrackingStore.instance();
      await store.saveSelection(
        entryId: 'e4',
        option: HelpedTrackingOption.paused,
        entryCountAtCapture: 4,
      );

      final report = PrivateArchiveReportEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final helped = report.sections[2];
      expect(helped.hasEvidence, isTrue);
      expect(helped.lines.first, contains('paused'));
    });

    test('what-to-watch-next section appears', () {
      final report = PrivateArchiveReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final watch = report.sections[4];
      expect(watch.heading, PrivateArchiveReportCopy.whatToWatchNextHeading);
      expect(watch.lines.first.trim(), isNotEmpty);
      expect(watch.hasEvidence, isTrue);
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
        entries: _fourRelatedRepeatEntries(),
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
        entries: _fourRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;

      final preview = report.plainText(isPro: false);
      expect(preview, contains(PrivateArchiveReportCopy.previewTitle));
      expect(preview, contains(PrivateArchiveReportCopy.previewBody));
      expect(preview, contains(PrivateArchiveReportCopy.whatRepeatedHeading));
      expect(
        preview,
        isNot(contains(PrivateArchiveReportCopy.whatChangedHeading)),
      );
      expect(
        preview,
        isNot(contains(PrivateArchiveReportCopy.whatToWatchNextHeading)),
      );

      final full = report.plainText(isPro: true);
      expect(full, isNot(contains(PrivateArchiveReportCopy.previewTitle)));
      expect(full, contains(PrivateArchiveReportCopy.whatChangedHeading));
      expect(full, contains(PrivateArchiveReportCopy.whatToWatchNextHeading));
    });

    test('preview explains full report without entitlement changes', () {
      expect(PrivateArchiveReportCopy.previewTitle, 'Preview private report');
      expect(
        PrivateArchiveReportCopy.exportIncludedItems,
        PrivateReportCopy.includedItems,
      );
      expect(
        PrivateArchiveReportCopy.exportNotIncludedItems,
        PrivateReportCopy.notIncludedItems,
      );
      expect(
        PrivateArchiveReportCopy.previewBody.toLowerCase(),
        contains('your first repeat'),
      );
      expect(PrivateArchiveReportCopy.intro, PrivateReportCopy.subtitle);
    });

    test('private report is evidence summary not coaching report', () {
      final joined = [
        PrivateArchiveReportCopy.intro,
        PrivateArchiveReportCopy.previewBody,
        PrivateArchiveReportCopy.whatHelpedHeading,
      ].join(' ').toLowerCase();

      expect(joined, contains('private summary'));
      expect(joined, contains('saved moments'));
      expect(joined, isNot(contains('recommendations')));
      expect(joined, isNot(contains('you should')));
      expect(joined, isNot(contains('try this')));
    });
  });

  group('PrivateArchiveReportCard', () {
    testWidgets('copy report and view report CTAs appear', (tester) async {
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

      expect(find.text(PrivateArchiveReportCopy.copyReportCta), findsOneWidget);
      expect(find.text(PrivateArchiveReportCopy.viewReportCta), findsOneWidget);
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
      await tester.tap(
        find.byKey(const Key('private_archive_report_copy_cta')),
      );
      await tester.pump();

      expect(copiedText, contains(PrivateArchiveReportCopy.title));
      expect(
        copiedText,
        contains(PrivateArchiveReportCopy.whatRepeatedHeading),
      );
      expect(copiedText, contains(PrivateReportCopy.footer));
      expect(copiedText.toLowerCase(), isNot(contains('.m4a')));
    });

    testWidgets('pro full export still includes all report sections', (
      tester,
    ) async {
      final report = PrivateArchiveReportEngine.build(
        entries: _fourRelatedRepeatEntries(),
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
      await tester.tap(
        find.byKey(const Key('private_archive_report_copy_cta')),
      );
      await tester.pump();

      expect(copiedText, contains(PrivateArchiveReportCopy.whatChangedHeading));
      expect(
        copiedText,
        contains(PrivateArchiveReportCopy.whatToWatchNextHeading),
      );
      expect(
        copiedText,
        isNot(contains(PrivateArchiveReportCopy.previewTitle)),
      );
    });

    testWidgets('free preview shows See Pro without full report sections', (
      tester,
    ) async {
      final report = PrivateArchiveReportEngine.build(
        entries: _fourRelatedRepeatEntries(),
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

      expect(find.text(PrivateArchiveReportCopy.previewTitle), findsOneWidget);
      expect(find.text(PrivateArchiveReportCopy.previewProCta), findsOneWidget);
      expect(
        find.text(PrivateArchiveReportCopy.whatToWatchNextHeading),
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
        EarlyFirstSignalEngine.build(
          entries: _threeRelatedRepeatEntries(),
        )?.showsConfirmedRepeat,
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
}
