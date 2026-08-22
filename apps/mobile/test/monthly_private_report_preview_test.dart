import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_model.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import 'package:archiveme_mobile/features/helped_tracking/helped_tracking_model.dart';
import 'package:archiveme_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:archiveme_mobile/features/monthly_private_report/monthly_private_report_analytics.dart';
import 'package:archiveme_mobile/features/monthly_private_report/monthly_private_report_copy.dart';
import 'package:archiveme_mobile/features/monthly_private_report/monthly_private_report_dismiss_store.dart';
import 'package:archiveme_mobile/features/monthly_private_report/monthly_private_report_engine.dart';
import 'package:archiveme_mobile/features/monthly_private_report/monthly_private_report_model.dart';
import 'package:archiveme_mobile/features/private_report/private_report_copy.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/pro/monthly_private_report_preview_card.dart';
import 'package:archiveme_mobile/widgets/pro/monthly_private_report_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

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

List<JournalEntry> _threeRelatedEntries() => [
  _entry(
    id: 'e1',
    transcript: _strongRepeat,
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

List<JournalEntry> _fourRelatedEntries() => [
  ..._threeRelatedEntries(),
  _entry(
    id: 'e4',
    transcript:
        'I said yes again even though I had no capacity for one more ask today.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

void _seedWatch({required String createdDateKey}) {
  ComeBackTomorrowV2Store.seedForTest(
    ActiveWatchTarget(
      watchKey: 'said yes again',
      groundedPhrase: 'said yes again',
      createdDateKey: createdDateKey,
      source: 'second_related_save',
    ),
  );
}

List<JournalEntry> _entriesWithQuietSignal() {
  _seedWatch(createdDateKey: '2026-06-14');
  return [
    ..._fourRelatedEntries(),
    _entry(
      id: 'u1',
      transcript: 'A quiet lunch with a friend — nothing about work.',
      createdAt: DateTime(2026, 6, 14, 16),
    ),
    _entry(
      id: 'u2',
      transcript: 'Went for a walk and noticed the weather.',
      createdAt: DateTime(2026, 6, 15, 12),
    ),
  ];
}

MonthlyPrivateReportContext _context({
  List<JournalEntry> entries = const [],
  int entryCount = 0,
  bool isPro = false,
  bool dismissed = false,
  MonthlyPrivateReportSurface surface =
      MonthlyPrivateReportSurface.archivePatterns,
  bool isZeroEntryState = false,
  bool isFirstRecordingState = false,
  bool isDegradedTranscriptState = false,
  bool isPostSaveDegradedState = false,
  bool firstProofTruthQuestionActive = false,
  bool whatChangedQuestionActive = false,
  bool proLockMomentVisible = false,
  bool proEvidenceValueVisible = false,
  MonthlyPrivateReportPreview? preview,
}) {
  return MonthlyPrivateReportEngine.buildContext(
    surface: surface,
    entryCount: entryCount,
    isPro: isPro,
    dismissed: dismissed,
    entries: entries,
    preview: preview,
    isZeroEntryState: isZeroEntryState,
    isFirstRecordingState: isFirstRecordingState,
    isDegradedTranscriptState: isDegradedTranscriptState,
    isPostSaveDegradedState: isPostSaveDegradedState,
    firstProofTruthQuestionActive: firstProofTruthQuestionActive,
    whatChangedQuestionActive: whatChangedQuestionActive,
    proLockMomentVisible: proLockMomentVisible,
    proEvidenceValueVisible: proEvidenceValueVisible,
  );
}

void main() {
  late TestStorageSandbox sandbox;
  TestWidgetsFlutterBinding.ensureInitialized();

  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    analyticsEvents.clear();
    MonthlyPrivateReportAnalytics.resetForTest();
    MonthlyPrivateReportAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    ComeBackTomorrowV2Store.seedForTest(null);
    await WhatChangedV2Store.resetForTest();
    await HelpedTrackingStore.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await MonthlyPrivateReportDismissStore.resetForTest();
  });

  tearDown(() => sandbox.dispose());
  tearDown(() {
    MonthlyPrivateReportAnalytics.resetForTest();
    analyticsEvents.clear();
    ComeBackTomorrowV2Store.seedForTest(null);
  });

  group('MonthlyPrivateReportCopy', () {
    test('defines required copy', () {
      expect(
        MonthlyPrivateReportCopy.cardTitle,
        'Your private monthly report is forming',
      );
      expect(
        MonthlyPrivateReportCopy.proReason,
        contains('longer proof trail'),
      );
      expect(
        MonthlyPrivateReportCopy.chatDifferentiation,
        contains('not a chat transcript'),
      );
    });

    test('copy says private report and evidence over time', () {
      final blob = MonthlyPrivateReportCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, contains('private'));
      expect(blob, contains('report'));
      expect(blob, contains('evidence'));
      expect(blob, contains('forming'));
    });

    test('does not claim therapy or medical benefit', () {
      for (final line in MonthlyPrivateReportCopy.allVisibleStrings()) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('therapy')));
        expect(lower, isNot(contains('diagnosis')));
        expect(lower, isNot(contains('treatment')));
        expect(lower, isNot(contains('medical')));
        expect(lower, isNot(contains('clinical')));
      }
    });

    test('does not promise PDF export', () {
      for (final line in MonthlyPrivateReportCopy.allVisibleStrings()) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('pdf')));
        expect(lower, isNot(contains('download')));
      }
    });
  });

  group('MonthlyPrivateReportEngine.build', () {
    test('hidden with insufficient evidence', () {
      expect(
        MonthlyPrivateReportEngine.build(
          entries: [
            _entry(id: 'g1', transcript: 'This is a test to check function'),
            _entry(id: 'g2', transcript: 'This is a second test for pressure'),
            _entry(id: 'g3', transcript: 'Another test for the app today'),
          ],
        ),
        isNull,
      );
    });

    test('confirmed repeat shows what kept returning', () {
      final preview = MonthlyPrivateReportEngine.build(
        entries: _threeRelatedEntries(),
      )!;
      expect(
        preview.sections.any(
          (section) =>
              section.type ==
                  MonthlyPrivateReportSectionType.whatKeptReturning &&
              section.heading ==
                  MonthlyPrivateReportCopy.whatKeptReturningHeading,
        ),
        isTrue,
      );
    });

    test('change evidence shows what changed', () async {
      await WhatChangedV2Store.instance().saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.softer,
        entryCountAtCapture: 4,
      );
      final preview = MonthlyPrivateReportEngine.build(
        entries: _fourRelatedEntries(),
      )!;
      expect(
        preview.sections.any(
          (section) =>
              section.type == MonthlyPrivateReportSectionType.whatChanged,
        ),
        isTrue,
      );
    });

    test('helped evidence shows what helped', () async {
      await HelpedTrackingStore.instance().saveSelection(
        entryId: 'e4',
        option: HelpedTrackingOption.paused,
        entryCountAtCapture: 4,
      );
      final preview = MonthlyPrivateReportEngine.build(
        entries: _fourRelatedEntries(),
      )!;
      expect(
        preview.sections.any(
          (section) =>
              section.type == MonthlyPrivateReportSectionType.whatHelped,
        ),
        isTrue,
      );
    });

    test('quiet evidence shows what went quiet', () {
      final preview = MonthlyPrivateReportEngine.build(
        entries: _entriesWithQuietSignal(),
      )!;
      expect(
        preview.sections.any(
          (section) =>
              section.type == MonthlyPrivateReportSectionType.whatWentQuiet,
        ),
        isTrue,
      );
    });

    test('no invented evidence', () {
      final preview = MonthlyPrivateReportEngine.build(
        entries: _threeRelatedEntries(),
      )!;
      for (final section in preview.sections) {
        for (final line in section.lines) {
          expect(line, isNot(contains(PrivateReportCopy.sectionFallback)));
          expect(line.trim(), isNotEmpty);
        }
      }
    });
  });

  group('MonthlyPrivateReportEngine.shouldShowCard', () {
    test('hidden for one entry without repeat evidence', () {
      expect(
        MonthlyPrivateReportEngine.shouldShowCard(
          _context(entries: [_threeRelatedEntries().first], entryCount: 1),
        ),
        isFalse,
      );
    });

    test('hidden for zero entries', () {
      expect(
        MonthlyPrivateReportEngine.shouldShowCard(
          _context(isZeroEntryState: true),
        ),
        isFalse,
      );
    });

    test('hidden for Pro users', () {
      final entries = _threeRelatedEntries();
      expect(
        MonthlyPrivateReportEngine.shouldShowCard(
          _context(entries: entries, entryCount: entries.length, isPro: true),
        ),
        isFalse,
      );
    });

    test('blocked during active review questions', () {
      final entries = _threeRelatedEntries();
      expect(
        MonthlyPrivateReportEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            firstProofTruthQuestionActive: true,
          ),
        ),
        isFalse,
      );
      expect(
        MonthlyPrivateReportEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            whatChangedQuestionActive: true,
          ),
        ),
        isFalse,
      );
    });

    test('blocked during degraded transcript', () {
      final entries = _threeRelatedEntries();
      expect(
        MonthlyPrivateReportEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            isDegradedTranscriptState: true,
          ),
        ),
        isFalse,
      );
      expect(
        MonthlyPrivateReportEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            isPostSaveDegradedState: true,
          ),
        ),
        isFalse,
      );
    });

    test('blocked when Pro Lock Moment is higher priority', () {
      final entries = _threeRelatedEntries();
      expect(
        MonthlyPrivateReportEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            proLockMomentVisible: true,
          ),
        ),
        isFalse,
      );
    });

    test('blocked when Pro Evidence Value is higher priority', () {
      final entries = _threeRelatedEntries();
      expect(
        MonthlyPrivateReportEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            proEvidenceValueVisible: true,
          ),
        ),
        isFalse,
      );
    });

    test('blocked during pattern review inbox items', () {
      final entries = _threeRelatedEntries();
      expect(
        MonthlyPrivateReportEngine.shouldShowCard(
          _context(entries: entries, entryCount: entries.length),
        ),
        isFalse,
      );
    });

    test('shown with confirmed repeat evidence', () {
      final entries = _threeRelatedEntries();
      final preview = MonthlyPrivateReportEngine.build(entries: entries)!;
      expect(
        MonthlyPrivateReportEngine.shouldShowCard(
          MonthlyPrivateReportContext(
            surface: MonthlyPrivateReportSurface.archivePatterns,
            entryCount: entries.length,
            isPro: false,
            dismissed: false,
            hasConfirmedRepeat: true,
            preview: preview,
            isZeroEntryState: false,
            isFirstRecordingState: false,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: false,
            firstProofTruthQuestionActive: false,
            whatChangedQuestionActive: false,
            patternReviewInboxHasActiveItems: false,
            proLockMomentVisible: false,
            proEvidenceValueVisible: false,
          ),
        ),
        isTrue,
      );
    });

    test('hidden when dismissed', () async {
      final entries = _threeRelatedEntries();
      await MonthlyPrivateReportDismissStore.dismiss();
      expect(
        MonthlyPrivateReportEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            dismissed: MonthlyPrivateReportDismissStore.isDismissed(),
          ),
        ),
        isFalse,
      );
    });
  });

  group('MonthlyPrivateReportPreviewCard', () {
    testWidgets('CTA opens sheet', (tester) async {
      final preview = MonthlyPrivateReportEngine.build(
        entries: _threeRelatedEntries(),
      )!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MonthlyPrivateReportPreviewCard(
              surface: MonthlyPrivateReportSurface.archivePatterns,
              entryCount: 3,
              preview: preview,
              onSeePro: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('monthly_private_report_preview_card')),
        findsOneWidget,
      );
      expect(find.text(MonthlyPrivateReportCopy.cardTitle), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('monthly_private_report_preview_cta')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('monthly_private_report_preview_sheet_title')),
        findsOneWidget,
      );
      expect(
        analyticsEvents.any(
          (event) =>
              event.event == MonthlyPrivateReportAnalytics.ctaTappedEvent,
        ),
        isTrue,
      );
    });

    testWidgets('tracks seen analytics', (tester) async {
      final preview = MonthlyPrivateReportEngine.build(
        entries: _threeRelatedEntries(),
      )!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MonthlyPrivateReportPreviewCard(
              surface: MonthlyPrivateReportSurface.archivePatterns,
              entryCount: 3,
              preview: preview,
              onSeePro: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        analyticsEvents.any(
          (event) => event.event == MonthlyPrivateReportAnalytics.seenEvent,
        ),
        isTrue,
      );
    });
  });

  group('MonthlyPrivateReportPreviewSheet', () {
    testWidgets('renders only preview sections with evidence', (tester) async {
      final preview = MonthlyPrivateReportEngine.build(
        entries: _threeRelatedEntries(),
      )!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MonthlyPrivateReportPreviewSheet(
              surface: MonthlyPrivateReportSurface.archivePatterns,
              entryCount: 3,
              preview: preview,
              onSeePro: () {},
            ),
          ),
        ),
      );

      expect(
        find.text(MonthlyPrivateReportCopy.whatKeptReturningHeading),
        findsOneWidget,
      );
      expect(
        find.text(MonthlyPrivateReportCopy.whatChangedHeading),
        findsNothing,
      );
      expect(
        find.text(MonthlyPrivateReportCopy.chatDifferentiation),
        findsOneWidget,
      );
      expect(find.text(MonthlyPrivateReportCopy.proReason), findsOneWidget);
    });
  });
}