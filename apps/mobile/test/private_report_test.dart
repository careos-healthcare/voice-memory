import 'dart:io';

import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/early_archive/private_archive_report_engine.dart';
import 'package:archiveme_mobile/features/helped_tracking/helped_tracking_model.dart';
import 'package:archiveme_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:archiveme_mobile/features/private_report/private_report_analytics.dart';
import 'package:archiveme_mobile/features/private_report/private_report_builder.dart';
import 'package:archiveme_mobile/features/private_report/private_report_copy.dart';
import 'package:archiveme_mobile/features/private_report/private_report_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_copy.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/widgets/private_report/private_report_sheet.dart';
import 'package:archiveme_mobile/widgets/record/private_archive_report_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? localAudioPath,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: localAudioPath ?? '/tmp/$id.m4a',
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

RepeatReturnCheckRecord _answeredRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
}) => RepeatReturnCheckRecord(
  entryId: entryId,
  choice: choice,
  entryCountAtCapture: 5,
  createdAt: DateTime(2026, 6, 14),
);

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    PrivateReportAnalytics.resetForTest();
    // AppServices.resetForTest must run first so the prefs-backed resets below
    // write into this test's fresh sandbox and not the previous test's
    // already-disposed one.
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await WhatChangedV2Store.resetForTest();
    await HelpedTrackingStore.resetForTest();
  });

  tearDown(() => sandbox.dispose());
  tearDown(() async {
    await WhatChangedV2Store.resetForTest();
    await HelpedTrackingStore.resetForTest();
  });

  group('PrivateReportCopy', () {
    test('v1 copy is stable', () {
      expect(PrivateReportCopy.title, 'My ArchiveMe report');
      expect(PrivateReportCopy.whatHelpedHeading, 'What seemed to help');
      expect(PrivateReportCopy.evidenceHeading, 'Evidence from saved moments');
      expect(PrivateReportCopy.copyReportCta, 'Copy report');
      expect(PrivateReportCopy.shareReportCta, 'Share report');
      expect(PrivateReportCopy.closeCta, 'Close');
      expect(
        PrivateReportCopy.insufficientEvidence,
        'ArchiveMe needs more evidence before creating a private report.',
      );
      expect(PrivateReportCopy.footer, contains('not advice or a diagnosis'));
    });
  });

  group('PrivateReportEngine', () {
    test('returns null when no pattern foundation', () {
      expect(
        PrivateReportEngine.build(
          entries: [
            _entry(id: 'g1', transcript: 'This is a test to check function'),
            _entry(id: 'g2', transcript: 'This is a second test for pressure'),
            _entry(id: 'g3', transcript: 'Another test for the app today'),
          ],
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });

    test('tracks hasChange and hasHelped metadata', () async {
      final store = WhatChangedV2Store.instance();
      await store.saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.softer,
        entryCountAtCapture: 4,
      );
      await HelpedTrackingStore.instance().saveSelection(
        entryId: 'e4',
        option: HelpedTrackingOption.paused,
        entryCountAtCapture: 4,
      );

      final result = PrivateReportEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;

      expect(result.hasChange, isTrue);
      expect(result.hasHelped, isTrue);
    });
  });

  group('PrivateReportBuilder safety', () {
    test('report excludes audio paths debug labels and internal ids', () {
      final report = PrivateReportBuilder.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final text = report.fullPlainText.toLowerCase();
      expect(text, isNot(contains('.m4a')));
      expect(text, isNot(contains('localaudiopath')));
      expect(text, isNot(contains('entry_id')));
      expect(text, isNot(contains('revenuecat')));
      expect(text, isNot(contains('restore purchases')));
      expect(text, contains('not advice or a diagnosis'));
    });

    test('report excludes pending placeholders', () {
      expect(
        PrivateReportBuilder.build(
          entries: [
            _degradedVoiceEntry(),
            _degradedVoiceEntry(id: 'v2'),
            _degradedVoiceEntry(id: 'v3'),
          ],
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });

    test('report sections render in v1 order', () {
      final report = PrivateReportBuilder.build(
        entries: _fourRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      expect(report.sections.map((section) => section.heading).toList(), [
        PrivateReportCopy.whatRepeatedHeading,
        PrivateReportCopy.whatChangedHeading,
        PrivateReportCopy.whatHelpedHeading,
        PrivateReportCopy.evidenceHeading,
        PrivateReportCopy.whatToWatchNextHeading,
      ]);
    });

    test('report includes grounded repeated phrase', () {
      final report = PrivateReportBuilder.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final repeated = report.sections.first;
      expect(repeated.hasEvidence, isTrue);
      expect(repeated.lines.first, contains('showed up across'));
    });

    test('report includes what-changed marker if available', () async {
      final store = WhatChangedV2Store.instance();
      await store.saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.softer,
        entryCountAtCapture: 4,
      );

      final report = PrivateReportBuilder.build(
        entries: _fourRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final changed = report.sections[1];
      expect(changed.hasEvidence, isTrue);
      expect(changed.lines.first, WhatChangedV2Copy.payoffSofter);
    });

    test('report includes helped marker if available', () async {
      await HelpedTrackingStore.instance().saveSelection(
        entryId: 'e4',
        option: HelpedTrackingOption.paused,
        entryCountAtCapture: 4,
      );

      final report = PrivateReportBuilder.build(
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

    test('report includes up to three evidence snippets', () {
      final report = PrivateReportBuilder.build(
        entries: _fourRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final evidence = report.sections[3];
      expect(evidence.heading, PrivateReportCopy.evidenceHeading);
      expect(evidence.bullets.length, lessThanOrEqualTo(3));
      expect(evidence.bullets, isNotEmpty);
    });

    test('no full transcript dump', () {
      final entries = _threeRelatedRepeatEntries();
      final report = PrivateReportBuilder.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      for (final entry in entries) {
        if (entry.transcript.length > 48) {
          expect(report.fullPlainText, isNot(contains(entry.transcript)));
        }
      }
    });

    test('export text includes privacy footer not analytics counters', () {
      final report = PrivateReportBuilder.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final text = report.fullPlainText;
      expect(text, contains(PrivateReportCopy.footer));
      expect(text, isNot(contains('Debug logs')));
      expect(text, isNot(contains('analytics')));
    });
  });

  group('PrivateReportAnalytics', () {
    test('events contain metadata only', () {
      final events = <String, Map<String, Object>>{};
      PrivateReportAnalytics.captureForTest = (event, props) {
        events[event] = props;
      };

      PrivateReportAnalytics.opened(
        source: 'pattern_detail',
        entryCount: 4,
        hasChange: true,
        hasHelped: false,
      );
      PrivateReportAnalytics.copied(
        source: 'pattern_detail',
        entryCount: 4,
        hasChange: true,
        hasHelped: false,
      );
      PrivateReportAnalytics.shared(
        source: 'pattern_detail',
        entryCount: 4,
        hasChange: true,
        hasHelped: false,
      );

      expect(
        events.keys,
        containsAll([
          PrivateReportAnalytics.openedEvent,
          PrivateReportAnalytics.copiedEvent,
          PrivateReportAnalytics.sharedEvent,
        ]),
      );
      for (final props in events.values) {
        expect(props.keys, containsAll(['source', 'entry_count']));
        expect(props, isNot(contains('transcript')));
        final flat = props.values.join(' ').toLowerCase();
        expect(flat, isNot(contains('said yes')));
      }
    });
  });

  group('PrivateReportSheet', () {
    testWidgets('sheet shows copy share close and footer', (tester) async {
      final result = PrivateReportEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => PrivateReportSheet.show(
                  context,
                  report: result.report,
                  entryCount: 3,
                  source: 'test',
                  isPro: true,
                  hasChange: result.hasChange,
                  hasHelped: result.hasHelped,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('private_report_sheet')), findsOneWidget);
      expect(find.text(PrivateReportCopy.copyReportCta), findsOneWidget);
      expect(find.text(PrivateReportCopy.shareReportCta), findsOneWidget);
      expect(find.text(PrivateReportCopy.closeCta), findsOneWidget);
      expect(find.text(PrivateReportCopy.footer), findsOneWidget);
      expect(find.text(PrivateReportCopy.title), findsOneWidget);
    });
  });

  group('PrivateReport export copy', () {
    testWidgets('copy action copies safe visible text', (tester) async {
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

      expect(copiedText, contains(PrivateReportCopy.title));
      expect(copiedText, contains(PrivateReportCopy.whatRepeatedHeading));
      expect(copiedText, contains(PrivateReportCopy.footer));
      expect(copiedText.toLowerCase(), isNot(contains('.m4a')));
    });
  });

  group('protected areas untouched', () {
    test('RevenueCat product id unchanged', () {
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('feature files avoid billing entitlement and signing', () {
      const paths = [
        'lib/features/private_report/private_report_copy.dart',
        'lib/features/private_report/private_report_model.dart',
        'lib/features/private_report/private_report_engine.dart',
        'lib/features/private_report/private_report_analytics.dart',
        'lib/widgets/private_report/private_report_sheet.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('purchasepackage')));
        expect(content, isNot(contains('proentitlementid')));
        expect(content, isNot(contains('build_number')));
        expect(content, isNot(contains('productidentifier')));
      }
    });
  });
}
