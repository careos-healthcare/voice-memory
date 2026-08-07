import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_copy.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_engine.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_filter.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_item.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_model.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:voicememory_mobile/features/record_capture_modes/record_capture_mode_copy.dart';
import 'package:voicememory_mobile/features/transcript_correction/transcript_correction_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive_history/archive_history_sheet.dart';
import 'support/test_storage_sandbox.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';

JournalEntry _textEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
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
  syncStatus: SyncStatus.localOnly,
);

JournalEntry _degradedVoiceEntry({
  String id = 'pending',
  String transcript = _placeholder,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
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
  syncStatus: SyncStatus.pendingUpload,
);

List<JournalEntry> _mixedEntries() => [
  _textEntry(
    id: 'saved',
    transcript: 'A quiet moment about lunch with a friend today.',
    createdAt: DateTime(2026, 6, 14, 12),
  ),
  _textEntry(
    id: 'e1',
    transcript:
        'I said yes again even though I was already tired from work today.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
  _textEntry(
    id: 'e2',
    transcript:
        'I took responsibility again before asking anyone for help today.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
  _textEntry(
    id: 'quiet',
    transcript: RecordCaptureModeCopy.quietDayDefaultSaveText,
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _textEntry(
    id: 'ignored',
    transcript: 'hello checking mic test',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _degradedVoiceEntry(id: 'needs_words', createdAt: DateTime(2026, 6, 9, 12)),
];

ArchiveHistoryContent _mixedContent() =>
    ArchiveHistoryEngine.build(entries: _mixedEntries());

Future<void> _pumpSheet(
  WidgetTester tester,
  ArchiveHistoryContent content, {
  int entryCount = 6,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ArchiveHistorySheet(content: content, entryCount: entryCount),
      ),
    ),
  );
}

Future<void> _selectFilter(
  WidgetTester tester,
  ArchiveHistoryFilter filter,
) async {
  await tester.tap(
    find.byKey(
      Key(
        'archive_history_filter_chip_${ArchiveHistoryFilterEngine.filterKey(filter)}',
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await HelpedTrackingStore.resetForTest();
  });

  tearDown(() => sandbox.dispose());
  group('ArchiveHistoryFilterEngine', () {
    test('all filter shows every row most recent first', () {
      final content = _mixedContent();
      final filtered = ArchiveHistoryFilterEngine.apply(
        items: content.items,
        filter: ArchiveHistoryFilter.all,
      );

      expect(filtered, hasLength(content.items.length));
      expect(filtered.first.entryId, 'saved');
      expect(filtered.last.entryId, 'needs_words');
    });

    test('used as evidence filter only evidence rows', () {
      final content = _mixedContent();
      final filtered = ArchiveHistoryFilterEngine.apply(
        items: content.items,
        filter: ArchiveHistoryFilter.usedAsEvidence,
      );

      expect(filtered, hasLength(2));
      expect(
        filtered.every(
          (item) => item.status == ArchiveHistoryStatus.usedAsEvidence,
        ),
        isTrue,
      );
    });

    test('saved only filter only saved-only rows', () {
      final content = _mixedContent();
      final filtered = ArchiveHistoryFilterEngine.apply(
        items: content.items,
        filter: ArchiveHistoryFilter.savedOnly,
      );

      expect(filtered, isNotEmpty);
      expect(
        filtered.every((item) => item.status == ArchiveHistoryStatus.savedOnly),
        isTrue,
      );
      expect(filtered.any((item) => item.entryId == 'saved'), isTrue);
    });

    test('needs your words filter only repairable pending rows', () {
      final content = _mixedContent();
      final filtered = ArchiveHistoryFilterEngine.apply(
        items: content.items,
        filter: ArchiveHistoryFilter.needsYourWords,
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.entryId, 'needs_words');
      expect(filtered.single.status, ArchiveHistoryStatus.needsYourWords);
      expect(filtered.single.showAddWordsCta, isTrue);
    });

    test('quiet days filter only quiet-day entries', () {
      final content = _mixedContent();
      final filtered = ArchiveHistoryFilterEngine.apply(
        items: content.items,
        filter: ArchiveHistoryFilter.quietDays,
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.entryId, 'quiet');
      expect(filtered.single.isQuietDay, isTrue);
    });

    test('ignored filter only ignored rows', () {
      final content = _mixedContent();
      final filtered = ArchiveHistoryFilterEngine.apply(
        items: content.items,
        filter: ArchiveHistoryFilter.ignoredForPatterns,
      );

      expect(filtered, isNotEmpty);
      expect(
        filtered.every(
          (item) => item.status == ArchiveHistoryStatus.ignoredForPatterns,
        ),
        isTrue,
      );
      expect(filtered.any((item) => item.entryId == 'ignored'), isTrue);
    });

    test('helped filter only helped-marked rows', () async {
      await HelpedTrackingStore.instance().saveSelection(
        entryId: 'saved',
        option: HelpedTrackingOption.paused,
        entryCountAtCapture: 6,
      );

      final content = ArchiveHistoryEngine.build(entries: _mixedEntries());
      final filtered = ArchiveHistoryFilterEngine.apply(
        items: content.items,
        filter: ArchiveHistoryFilter.helped,
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.entryId, 'saved');
      expect(filtered.single.helpedNote, isNotNull);
    });
  });

  group('ArchiveHistorySheet filters', () {
    testWidgets('all filter chips render when history has entries', (
      tester,
    ) async {
      await _pumpSheet(tester, _mixedContent());

      expect(
        find.byKey(const Key('archive_history_filter_chips')),
        findsOneWidget,
      );
      for (final filter in ArchiveHistoryFilterEngine.orderedFilters) {
        expect(
          find.byKey(
            Key(
              'archive_history_filter_chip_${ArchiveHistoryFilterEngine.filterKey(filter)}',
            ),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('does not show filter chips when archive is empty', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        const ArchiveHistoryContent(items: [], isEmpty: true),
        entryCount: 0,
      );

      expect(
        find.byKey(const Key('archive_history_filter_chips')),
        findsNothing,
      );
      expect(find.text(ArchiveHistoryCopy.emptyTitle), findsOneWidget);
    });

    testWidgets('empty filtered state shows filter-specific copy', (
      tester,
    ) async {
      await _pumpSheet(tester, _mixedContent());
      await _selectFilter(tester, ArchiveHistoryFilter.helped);

      expect(
        find.byKey(const Key('archive_history_filtered_empty_title')),
        findsOneWidget,
      );
      expect(find.text(ArchiveHistoryCopy.filteredEmptyTitle), findsOneWidget);
      expect(find.text(ArchiveHistoryCopy.filteredEmptyBody), findsOneWidget);
      expect(find.byKey(const Key('archive_history_row_saved')), findsNothing);
    });

    testWidgets('used as evidence filter shows only evidence rows', (
      tester,
    ) async {
      await _pumpSheet(tester, _mixedContent());
      await _selectFilter(tester, ArchiveHistoryFilter.usedAsEvidence);

      expect(find.byKey(const Key('archive_history_row_e1')), findsOneWidget);
      expect(find.byKey(const Key('archive_history_row_e2')), findsOneWidget);
      expect(find.byKey(const Key('archive_history_row_saved')), findsNothing);
      expect(find.byKey(const Key('archive_history_row_quiet')), findsNothing);
    });

    testWidgets('saved only filter shows only saved-only rows', (tester) async {
      await _pumpSheet(tester, _mixedContent());
      await _selectFilter(tester, ArchiveHistoryFilter.savedOnly);

      expect(
        find.byKey(const Key('archive_history_row_saved')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('archive_history_row_e1')), findsNothing);
    });

    testWidgets('needs your words filter shows add words CTA', (tester) async {
      await _pumpSheet(tester, _mixedContent());
      await _selectFilter(tester, ArchiveHistoryFilter.needsYourWords);

      expect(
        find.byKey(const Key('archive_history_row_needs_words')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_history_add_words_needs_words')),
        findsOneWidget,
      );
      expect(find.text(ArchiveHistoryCopy.addWordsCta), findsOneWidget);
    });

    testWidgets('quiet days filter shows only quiet-day rows', (tester) async {
      await _pumpSheet(tester, _mixedContent());
      await _selectFilter(tester, ArchiveHistoryFilter.quietDays);

      expect(
        find.byKey(const Key('archive_history_row_quiet')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('archive_history_row_saved')), findsNothing);
    });

    testWidgets('ignored filter shows only ignored rows', (tester) async {
      await _pumpSheet(tester, _mixedContent());
      await _selectFilter(tester, ArchiveHistoryFilter.ignoredForPatterns);

      expect(
        find.byKey(const Key('archive_history_row_ignored')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('archive_history_row_saved')), findsNothing);
    });

    testWidgets('helped filter shows only helped-marked rows', (tester) async {
      await tester.runAsync(() async {
        await HelpedTrackingStore.instance().saveSelection(
          entryId: 'saved',
          option: HelpedTrackingOption.askedForTime,
          entryCountAtCapture: 6,
        );
      });
      final content = ArchiveHistoryEngine.build(entries: _mixedEntries());

      await _pumpSheet(tester, content);
      await _selectFilter(tester, ArchiveHistoryFilter.helped);

      expect(
        find.byKey(const Key('archive_history_row_saved')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_history_helped_saved')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('archive_history_row_e1')), findsNothing);
    });

    testWidgets('correct transcript still available on saved-only filter', (
      tester,
    ) async {
      final content = ArchiveHistoryEngine.build(
        entries: [
          _textEntry(
            id: 'hist1',
            transcript:
                "I said yes when I didn't have the cockpit's capability left today.",
          ),
        ],
      );

      await _pumpSheet(tester, content, entryCount: 1);
      await _selectFilter(tester, ArchiveHistoryFilter.savedOnly);

      expect(
        find.byKey(const Key('archive_history_correct_transcript_hist1')),
        findsOneWidget,
      );
      expect(find.text(TranscriptCorrectionCopy.actionLabel), findsOneWidget);
    });
  });

  group('integration untouched', () {
    test('copy avoids internal debug labels', () {
      final haystack = [
        ...ArchiveHistoryCopy.all,
        ...ArchiveHistoryFilterEngine.orderedFilters.map(
          ArchiveHistoryFilterEngine.label,
        ),
      ].join(' ').toLowerCase();

      for (final banned in [
        'revenuecat',
        'quality level',
        'score',
        'debug',
        'analytics',
        'entry_id',
      ]) {
        expect(haystack, isNot(contains(banned)), reason: banned);
      }
    });

    test('billing RevenueCat restore signing build files untouched', () {
      const paths = [
        'lib/features/archive_history/archive_history_filter.dart',
        'lib/features/archive_history/archive_history_engine.dart',
        'lib/widgets/archive_history/archive_history_sheet.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('revenuecat')));
        expect(content, isNot(contains('restorepurchase')));
        expect(content, isNot(contains('billing/')));
        expect(content, isNot(contains('build_number')));
      }
    });
  });
}
