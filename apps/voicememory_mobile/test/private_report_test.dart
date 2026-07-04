import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_engine.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_model.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:voicememory_mobile/features/private_report/private_report_builder.dart';
import 'package:voicememory_mobile/features/private_report/private_report_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/transcript_correction/transcript_correction_controller.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/widgets/private_report/private_report_sheet.dart';
import 'package:voicememory_mobile/widgets/record/private_archive_report_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? localAudioPath,
}) =>
    JournalEntry(
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
}) =>
    RepeatReturnCheckRecord(
      entryId: entryId,
      choice: choice,
      entryCountAtCapture: 5,
      createdAt: DateTime(2026, 6, 14),
    );

void main() {
  setUp(() async {
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

  group('PrivateReportCopy', () {
    test('spec copy is stable', () {
      expect(PrivateReportCopy.title, 'Private archive report');
      expect(
        PrivateReportCopy.subtitle,
        'A local summary you can copy. Your raw recordings are not included.',
      );
      expect(PrivateReportCopy.copyReportCta, 'Copy report');
      expect(PrivateReportCopy.closeCta, 'Close');
      expect(PrivateReportCopy.copySuccess, 'Private report copied');
      expect(PrivateReportCopy.notEnoughEvidence, 'Not enough evidence yet');
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
      expect(text, contains('not included'));
      expect(text, contains('debug logs'));
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

    test('report excludes generic test text', () {
      expect(
        PrivateReportBuilder.build(
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

    test('report sections render in exact order', () {
      final report = PrivateReportBuilder.build(
        entries: _fourRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      expect(
        report.sections.map((section) => section.heading).toList(),
        [
          PrivateReportCopy.whatRepeatedHeading,
          PrivateReportCopy.whatChangedHeading,
          PrivateReportCopy.whatHelpedHeading,
          PrivateReportCopy.whatToWatchNextHeading,
          PrivateReportCopy.evidenceHeading,
        ],
      );
    });

    test('report includes grounded repeated phrase', () {
      final report = PrivateReportBuilder.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final repeated = report.sections.first;
      expect(repeated.hasEvidence, isTrue);
      expect(repeated.lines.first, contains('showed up across'));
      final match = RegExp(r'"([^"]+)"').firstMatch(repeated.lines.first);
      expect(match, isNotNull);
      final words = match!.group(1)!.trim().split(RegExp(r'\s+'));
      expect(words.length, lessThanOrEqualTo(6));
    });

    test('not enough evidence fallback when section lacks proof', () {
      final report = PrivateReportBuilder.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      expect(
        report.sections[1].lines.first,
        PrivateReportCopy.notEnoughEvidence,
      );
      expect(
        report.sections[2].lines.first,
        PrivateReportCopy.notEnoughEvidence,
      );
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
      expect(
        changed.lines.first,
        'You marked that the repeat felt softer this time.',
      );
    });

    test('report includes helped marker if available', () async {
      final store = HelpedTrackingStore.instance();
      await store.saveSelection(
        entryId: 'e4',
        option: HelpedTrackingOption.paused,
        entryCountAtCapture: 4,
      );

      final report = PrivateReportBuilder.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final helped = report.sections[2];
      expect(helped.hasEvidence, isTrue);
      expect(helped.lines.first, contains('paused'));
    });

    test('report includes user-corrected text when used as evidence', () async {
      const misheard =
          "I said yes when I didn't have the cockpit's capability left today.";
      const corrected =
          'I said yes again before checking capacity at work today.';

      await AppServices.instance.journalStore.save(
        _entry(
          id: 'c1',
          transcript: misheard,
          createdAt: DateTime(2026, 6, 10, 12),
        ),
      );
      await AppServices.instance.journalStore.save(
        _entry(
          id: 'c2',
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
      );
      await AppServices.instance.journalStore.save(
        _entry(
          id: 'c3',
          transcript:
              'I said yes again even though I had no capacity for one more ask.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      );

      await TranscriptCorrectionController.apply(
        entry: _entry(id: 'c1', transcript: misheard),
        correctedText: corrected,
      );

      final entries = await AppServices.instance.journalStore.loadAll();
      final report = PrivateReportBuilder.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final evidence = report.sections.last;
      expect(evidence.heading, PrivateReportCopy.evidenceHeading);
      final joined = evidence.bullets.join('\n').toLowerCase();
      expect(joined, contains('checking capacity'));
      expect(joined, isNot(contains('cockpit')));
    });

    test('no full transcript dump', () {
      final entries = _threeRelatedRepeatEntries();
      final report = PrivateReportBuilder.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      for (final entry in entries) {
        if (entry.transcript.length > 48) {
          expect(
            report.fullPlainText,
            isNot(contains(entry.transcript)),
          );
        }
      }
      final evidence = report.sections.last.bullets.join('\n');
      for (final bullet in report.sections.last.bullets) {
        expect(bullet.length, lessThan(80));
      }
      expect(evidence, isNot(contains('localAudioPath')));
    });
  });

  group('PrivateReport export copy', () {
    test('included and not included scope lists are present in copy text', () {
      final report = PrivateReportBuilder.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final text = report.fullPlainText;
      expect(text, contains(PrivateReportCopy.includedHeading));
      expect(text, contains('Short pattern summaries'));
      expect(text, contains(PrivateReportCopy.notIncludedHeading));
      expect(text, contains('Audio files'));
      expect(text, contains('Billing information'));
      expect(text, isNot(contains('Made with ArchiveMe')));
    });

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
      await tester.tap(find.byKey(const Key('private_archive_report_copy_cta')));
      await tester.pump();

      expect(copiedText, contains(PrivateReportCopy.title));
      expect(copiedText, contains(PrivateReportCopy.whatRepeatedHeading));
      expect(copiedText, contains(PrivateReportCopy.includedHeading));
      expect(copiedText, contains(PrivateReportCopy.notIncludedHeading));
      expect(copiedText.toLowerCase(), isNot(contains('.m4a')));
    });
  });

  group('PrivateReportSheet', () {
    testWidgets('sheet shows copy and close actions', (tester) async {
      final report = PrivateReportBuilder.build(
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
                  report: report,
                  entryCount: 3,
                  surface: 'test',
                  isPro: true,
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
      expect(find.text(PrivateReportCopy.closeCta), findsOneWidget);
      expect(find.text(PrivateReportCopy.subtitle), findsOneWidget);
    });
  });
}
