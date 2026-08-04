import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_search/archive_entry_search_engine.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_filters.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_query.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_result.dart';
import 'package:voicememory_mobile/features/memory/archive_retrieval_policy.dart';
import 'package:voicememory_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:voicememory_mobile/features/memory/memory_control_model.dart';
import 'package:voicememory_mobile/features/memory/memory_influence_level.dart';
import 'package:voicememory_mobile/features/memory/memory_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/pins/pinned_evidence_store.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/screens/journal_screen.dart';
import 'package:voicememory_mobile/screens/pinned_evidence_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive_search/archive_filter_chips.dart';
import 'package:voicememory_mobile/widgets/archive_search/archive_search_bar.dart';
import 'package:voicememory_mobile/widgets/archive_search/archive_search_result_card.dart';
import 'package:voicememory_mobile/widgets/pins/pin_entry_button.dart';

import 'support/widget_test_pump.dart';

const _engine = ArchiveEntrySearchEngine();
const _framingEngine = MemoryAuthorityFramingEngine();

final DateTime _base = DateTime(2026, 6, 12, 12);

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

const String _privatePhrase = 'confidential launch plan with dana';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 4,
  recurringThemes: ['work'],
  exactLanguagePattern: 'I need quiet',
  concreteObservation: 'You asked for quiet time.',
  repeatedSignal: 'Quiet mentioned twice.',
);

JournalEntry _entry({
  required String id,
  String transcript = 'A regular reflection about the day',
  int daysAgo = 0,
  bool treatAsNew = false,
  bool connectionApproved = false,
  bool keepExactDetails = false,
  bool isPinned = false,
}) => JournalEntry(
  id: id,
  createdAt: _base.subtract(Duration(days: daysAgo, hours: 1)),
  transcript: transcript,
  durationSeconds: 10,
  reflection: _reflection(),
  syncStatus: SyncStatus.localOnly,
  treatAsNew: treatAsNew,
  connectionApproved: connectionApproved,
  keepExactDetails: keepExactDetails,
  isPinned: isPinned,
  pinnedAt: isPinned ? _base : null,
);

PressureCheckInRecord _rec({
  required String entryId,
  required int daysAgo,
  List<String> contexts = const ['work'],
  bool treatAsNew = false,
  bool connectionApproved = false,
  bool keepExactDetails = false,
}) => PressureCheckInRecord(
  entryId: entryId,
  createdAt: _base.subtract(Duration(days: daysAgo, hours: 1)),
  optionId: 'could_not_stop',
  contextIds: contexts,
  treatAsNew: treatAsNew,
  connectionApproved: connectionApproved,
  keepExactDetails: keepExactDetails,
);

List<ArchiveEntrySearchResult> _search(
  List<JournalEntry> entries, {
  List<PressureCheckInRecord> records = const [],
  ArchiveEntrySearchQuery query = const ArchiveEntrySearchQuery(),
}) => _engine.search(
  entries: entries,
  records: records,
  query: query,
  now: _base,
);

/// Every consumer copy constant this feature introduces.
List<String> _consumerCopy() => [
  ArchiveSearchCopy.searchPlaceholder,
  ArchiveSearchCopy.emptyTitle,
  ArchiveSearchCopy.emptyHelper,
  ArchiveSearchCopy.filterHeading,
  ArchiveSearchCopy.clearFilters,
  ArchiveSearchCopy.exactEvidenceLabel,
  ArchiveSearchCopy.pinnedLabel,
  PinnedEvidenceCopy.pinLabel,
  PinnedEvidenceCopy.pinnedLabel,
  PinnedEvidenceCopy.pinAccessibilityLabel,
  PinnedEvidenceCopy.unpinAccessibilityLabel,
  PinnedEvidenceCopy.pinnedReceipt,
  PinnedEvidenceCopy.unpinnedReceipt,
  PinnedEvidenceCopy.settingsTitle,
  PinnedEvidenceCopy.settingsSubtitle,
  PinnedEvidenceCopy.screenTitle,
  PinnedEvidenceCopy.emptyTitle,
  PinnedEvidenceCopy.emptyHelper,
  for (final f in ArchiveDateFilter.values) f.label,
  for (final s in ArchiveMemoryStatus.values) s.label,
];

void main() {
  setUp(() {
    MemoryScopePolicy.resetForTest();
    ArchiveRetrievalPolicy.resetSessionForTest();
    MemoryAuthorityFrameLog.resetForTest();
    ActivationFunnelAnalytics.resetForTest();
    _events.clear();
    ActivationFunnelAnalytics.captureForTest(
      (name, properties) => _events.add(_Event(name, properties)),
    );
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  group('Archive Search 2.0 — engine', () {
    test('search by keyword returns matching entries', () {
      final entries = [
        _entry(id: 'a', transcript: 'Planning the product launch with Dana'),
        _entry(id: 'b', transcript: 'A quiet morning walk'),
        _entry(id: 'c', transcript: ''),
        _entry(id: 'd', transcript: '[draft] launch placeholder'),
      ];
      final results = _search(
        entries,
        query: const ArchiveEntrySearchQuery(keyword: 'launch'),
      );
      expect(results.map((r) => r.entry.id), ['a']);

      // Keyword also matches safe reflection fields.
      final byObservation = _search(
        entries,
        query: const ArchiveEntrySearchQuery(keyword: 'quiet time'),
      );
      expect(byObservation.map((r) => r.entry.id), ['a', 'b']);

      // Case insensitive.
      expect(
        _search(
          entries,
          query: const ArchiveEntrySearchQuery(keyword: 'LAUNCH'),
        ).length,
        1,
      );
    });

    test('search by context tag works', () {
      final entries = [_entry(id: 'a'), _entry(id: 'b')];
      final records = [
        _rec(entryId: 'a', daysAgo: 0, contexts: ['work']),
        _rec(entryId: 'b', daysAgo: 0, contexts: ['family']),
      ];
      final results = _search(
        entries,
        records: records,
        query: const ArchiveEntrySearchQuery(contextTagId: 'work'),
      );
      expect(results.map((r) => r.entry.id), ['a']);
      expect(results.single.contextTagLabels, ['Work']);

      // Available tags come from the fixed enum, never free text.
      final tags = _engine.availableContextTags(records);
      expect(tags.map((t) => t.id), containsAll(['work', 'family']));
    });

    test('date filters work', () {
      final entries = [
        _entry(id: 'today', daysAgo: 0),
        _entry(id: 'week', daysAgo: 4),
        _entry(id: 'month', daysAgo: 20),
        _entry(id: 'older', daysAgo: 60),
      ];
      expect(
        _search(
          entries,
          query: const ArchiveEntrySearchQuery(
            dateFilter: ArchiveDateFilter.today,
          ),
        ).map((r) => r.entry.id),
        ['today'],
      );
      expect(
        _search(
          entries,
          query: const ArchiveEntrySearchQuery(
            dateFilter: ArchiveDateFilter.thisWeek,
          ),
        ).map((r) => r.entry.id),
        ['week'],
      );
      expect(
        _search(
          entries,
          query: const ArchiveEntrySearchQuery(
            dateFilter: ArchiveDateFilter.thisMonth,
          ),
        ).map((r) => r.entry.id),
        ['month'],
      );
      expect(
        _search(
          entries,
          query: const ArchiveEntrySearchQuery(
            dateFilter: ArchiveDateFilter.older,
          ),
        ).map((r) => r.entry.id),
        ['older'],
      );
    });

    test('memory status filters work', () {
      final entries = [
        _entry(id: 'fresh', treatAsNew: true),
        _entry(id: 'confirmed', connectionApproved: true),
        _entry(id: 'mixed'),
        _entry(id: 'changed', daysAgo: 20),
        _entry(id: 'stale', daysAgo: 40),
        _entry(id: 'current'),
      ];
      final records = [
        _rec(entryId: 'changed', daysAgo: 20, contexts: ['work']),
        _rec(entryId: 'newer_work', daysAgo: 2, contexts: ['work']),
      ];
      ArchiveRetrievalPolicy.markRecordNotQuite('mixed');

      ArchiveEntrySearchQuery q(ArchiveMemoryStatus status) =>
          ArchiveEntrySearchQuery(memoryStatus: status);

      expect(
        _search(
          entries,
          records: records,
          query: q(ArchiveMemoryStatus.freshEntry),
        ).map((r) => r.entry.id),
        ['fresh'],
      );
      expect(
        _search(
          entries,
          records: records,
          query: q(ArchiveMemoryStatus.userConfirmed),
        ).map((r) => r.entry.id),
        ['confirmed'],
      );
      expect(
        _search(
          entries,
          records: records,
          query: q(ArchiveMemoryStatus.mixedEvidence),
        ).map((r) => r.entry.id),
        ['mixed'],
      );
      expect(
        _search(
          entries,
          records: records,
          query: q(ArchiveMemoryStatus.changedLater),
        ).map((r) => r.entry.id),
        ['changed'],
      );
      expect(
        _search(
          entries,
          records: records,
          query: q(ArchiveMemoryStatus.mayBeStale),
        ).map((r) => r.entry.id),
        ['stale'],
      );
      expect(
        _search(
          entries,
          records: records,
          query: q(ArchiveMemoryStatus.stillCurrent),
        ).map((r) => r.entry.id),
        ['current'],
      );
    });

    test('exact evidence filter works', () {
      final entries = [
        _entry(id: 'exact', keepExactDetails: true),
        _entry(id: 'plain'),
        _entry(id: 'record_exact'),
      ];
      final records = [
        _rec(entryId: 'record_exact', daysAgo: 0, keepExactDetails: true),
      ];
      final results = _search(
        entries,
        records: records,
        query: const ArchiveEntrySearchQuery(exactEvidenceOnly: true),
      );
      expect(results.map((r) => r.entry.id).toSet(), {'exact', 'record_exact'});
      expect(results.every((r) => r.isExactEvidence), isTrue);
    });

    test('pinned filter works and pinned results sort first', () {
      final entries = [
        _entry(id: 'plain', daysAgo: 0),
        _entry(id: 'pinned_old', daysAgo: 10, isPinned: true),
      ];
      final pinnedOnly = _search(
        entries,
        query: const ArchiveEntrySearchQuery(pinnedOnly: true),
      );
      expect(pinnedOnly.map((r) => r.entry.id), ['pinned_old']);
      expect(pinnedOnly.single.isPinned, isTrue);

      // Pinned first in mixed results despite being older.
      final all = _search(
        entries,
        query: const ArchiveEntrySearchQuery(keyword: 'reflection'),
      );
      expect(all.map((r) => r.entry.id), ['pinned_old', 'plain']);
    });

    test('combined filters work', () {
      final entries = [
        _entry(
          id: 'match',
          transcript: 'Launch retro notes',
          daysAgo: 3,
          keepExactDetails: true,
          isPinned: true,
        ),
        _entry(
          id: 'wrong_week',
          transcript: 'Launch retro notes',
          daysAgo: 40,
          keepExactDetails: true,
          isPinned: true,
        ),
        _entry(
          id: 'not_exact',
          transcript: 'Launch retro notes',
          daysAgo: 3,
          isPinned: true,
        ),
      ];
      final records = [
        _rec(entryId: 'match', daysAgo: 3, contexts: ['work']),
        _rec(entryId: 'wrong_week', daysAgo: 40, contexts: ['work']),
        _rec(entryId: 'not_exact', daysAgo: 3, contexts: ['work']),
      ];
      final results = _search(
        entries,
        records: records,
        query: const ArchiveEntrySearchQuery(
          keyword: 'retro',
          contextTagId: 'work',
          dateFilter: ArchiveDateFilter.thisWeek,
          exactEvidenceOnly: true,
          pinnedOnly: true,
        ),
      );
      expect(results.map((r) => r.entry.id), ['match']);
    });

    test('search does not change memory state', () {
      MemoryScopePolicy.scope = MemoryScope.ask;
      final entries = [_entry(id: 'a', treatAsNew: true)];
      final records = [_rec(entryId: 'a', daysAgo: 0, treatAsNew: true)];
      _search(
        entries,
        records: records,
        query: const ArchiveEntrySearchQuery(keyword: 'regular'),
      );

      expect(MemoryScopePolicy.scope, MemoryScope.ask);
      expect(entries.single.treatAsNew, isTrue);
      expect(records.single.treatAsNew, isTrue);
      // No memory analytics fired from searching.
      expect(_events.where((e) => e.name.startsWith('memory_')), isEmpty);
    });
  });

  group('Search UI', () {
    testWidgets('no matching entries state renders', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late Directory dir;
      final journalPath =
          '${Directory.systemTemp.createTempSync('vm_search_screen_').path}/entries.json';
      dir = File(journalPath).parent;
      final prefsPath = '${dir.path}/prefs.json';
      for (final path in [
        journalPath,
        prefsPath,
        JournalStore.encryptedPathFor(journalPath),
      ]) {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      }
      await tester.runAsync(() async {
        await AppServices.resetForTest(
          journalPath: journalPath,
          prefsPath: prefsPath,
          skipRevenueCat: true,
        );
        await AppServices.instance.journalStore.save(
          _entry(id: 'a', transcript: 'Planning the product launch'),
        );
      });
      addTearDown(() async {
        await AppServices.disposeForTest();
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const JournalScreen(),
          ),
        ),
      );
      await pumpUntilFound(
        tester,
        find.byKey(const Key('first_archive_value_card')),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('first_archive_value_card')), findsOneWidget);
      expect(find.byKey(const Key('archive_search_empty_state')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('archive_search_bar')),
        'zzz-no-match',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const Key('archive_search_empty_state')),
        findsOneWidget,
      );
      expect(find.text('No matching entries'), findsOneWidget);
      expect(
        find.text('Try a different word, tag, or filter.'),
        findsOneWidget,
      );

      // A matching keyword brings the entry back as a result card.
      await tester.enterText(
        find.byKey(const Key('archive_search_bar')),
        'launch',
      );
      await tester.pump();
      expect(find.byKey(const Key('archive_search_result_a')), findsOneWidget);
    });

    testWidgets('search query is never logged or sent to analytics', (
      tester,
    ) async {
      final typed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ArchiveSearchBar(onChanged: typed.add)),
        ),
      );
      await tester.tap(find.byKey(const Key('archive_search_bar')));
      await tester.enterText(
        find.byKey(const Key('archive_search_bar')),
        _privatePhrase,
      );
      await tester.pump();

      // The query reached only the local callback.
      expect(typed.last, _privatePhrase);

      // Analytics saw a fixed open event and nothing query-shaped.
      expect(_events.map((e) => e.name), contains('archive_search_opened'));
      final payload = _events.map((e) => '${e.name} ${e.properties}').join(' ');
      expect(payload.contains('confidential'), isFalse);
      expect(payload.contains('dana'), isFalse);
      expect(payload.contains('launch'), isFalse);
    });

    testWidgets('filter chips track filter type only', (tester) async {
      var query = const ArchiveEntrySearchQuery();
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => ArchiveFilterChips(
                  query: query,
                  onChanged: (next) => setState(() => query = next),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Filter'), findsOneWidget);
      await tester.tap(find.byKey(const Key('archive_filter_date_today')));
      await tester.pump();
      expect(query.dateFilter, ArchiveDateFilter.today);

      await tester.tap(
        find.byKey(const Key('archive_filter_status_may_be_stale')),
      );
      await tester.pump();
      expect(query.memoryStatus, ArchiveMemoryStatus.mayBeStale);

      await tester.tap(find.byKey(const Key('archive_filter_pinned')));
      await tester.pump();
      expect(query.pinnedOnly, isTrue);

      await tester.tap(find.byKey(const Key('archive_clear_filters')));
      await tester.pump();
      expect(query.hasActiveFilters, isFalse);

      final filterEvents = _events
          .where((e) => e.name == 'archive_search_filter_used')
          .toList();
      expect(filterEvents.length, 4);
      expect(filterEvents.map((e) => e.properties['filter_type']), [
        'date',
        'memory_status',
        'pinned',
        'clear',
      ]);
      // Filter values themselves never enter the payload.
      for (final e in filterEvents) {
        expect(e.properties.values.contains('today'), isFalse);
        expect(e.properties.values.contains('may_be_stale'), isFalse);
      }
    });

    testWidgets('result card shows safe metadata badges', (tester) async {
      final servicesDir = Directory.systemTemp.createTempSync(
        'vm_search_result_services_',
      );
      await tester.runAsync(
        () => AppServices.resetForTest(
          journalPath: '${servicesDir.path}/journal.json',
          prefsPath: '${servicesDir.path}/prefs.json',
          skipRevenueCat: true,
        ),
      );
      addTearDown(() async {
        await AppServices.disposeForTest();
        if (await servicesDir.exists()) {
          await servicesDir.delete(recursive: true);
        }
      });
      final result = ArchiveEntrySearchResult(
        entry: _entry(
          id: 'a',
          transcript: 'Planning the product launch',
          isPinned: true,
          keepExactDetails: true,
        ),
        timeBucket: ArchiveDateFilter.thisWeek,
        contextTagLabels: const ['Work'],
        isPinned: true,
        isExactEvidence: true,
        memoryStatus: ArchiveMemoryStatus.stillCurrent,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ArchiveSearchResultCard(result: result)),
        ),
      );
      expect(find.text('Planning the product launch'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('Exact evidence'), findsOneWidget);
      expect(find.text('Still current'), findsOneWidget);
    });
  });

  group('Pins / Saved Evidence', () {
    Future<(JournalStore, PinnedEvidenceStore, Directory)> openStores() async {
      final dir = Directory.systemTemp.createTempSync('vm_pins_');
      final journal = await JournalStore.open(
        '${dir.path}/entries.json',
        encryptAtRest: false,
      );
      return (journal, PinnedEvidenceStore.forStore(journal), dir);
    }

    test('pinned state persists after save/load', () async {
      final (journal, pins, dir) = await openStores();
      addTearDown(() => dir.deleteSync(recursive: true));
      await journal.save(_entry(id: 'a'));

      final pinned = await pins.setPinned('a', true, now: _base);
      expect(pinned!.isPinned, isTrue);
      expect(pinned.pinnedAt, _base);
      // Text and memory metadata untouched.
      expect(pinned.transcript, _entry(id: 'a').transcript);
      expect(pinned.treatAsNew, isFalse);
      expect(pinned.connectionApproved, isFalse);

      final reopened = await JournalStore.open(
        '${dir.path}/entries.json',
        encryptAtRest: false,
      );
      final reloaded = await reopened.getById('a');
      expect(reloaded!.isPinned, isTrue);
      expect(reloaded.pinnedAt, _base);

      // Unpin clears both fields and persists too.
      await pins.setPinned('a', false);
      final afterUnpin = await JournalStore.open(
        '${dir.path}/entries.json',
        encryptAtRest: false,
      );
      final unpinned = await afterUnpin.getById('a');
      expect(unpinned!.isPinned, isFalse);
      expect(unpinned.pinnedAt, isNull);
    });

    test('pin state survives a sync merge', () async {
      final (journal, pins, dir) = await openStores();
      addTearDown(() => dir.deleteSync(recursive: true));
      await journal.save(_entry(id: 'a'));
      await pins.setPinned('a', true, now: _base);

      // Remote copy of the same entry without local pin metadata.
      await journal.mergeRemote([_entry(id: 'a')]);
      final merged = await journal.getById('a');
      expect(merged!.isPinned, isTrue);
      expect(merged.pinnedAt, _base);
    });

    testWidgets('pin button toggles state with the agreed copy', (
      tester,
    ) async {
      late JournalStore journal;
      late PinnedEvidenceStore pins;
      late Directory dir;
      await tester.runAsync(() async {
        (journal, pins, dir) = await openStores();
        await journal.save(_entry(id: 'a'));
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PinEntryButton(entryId: 'a', isPinned: false, store: pins),
          ),
        ),
      );
      expect(find.text('Pin'), findsOneWidget);
      expect(find.bySemanticsLabel('Pin this entry'), findsOneWidget);

      final pinButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('pin_entry_button')),
      );
      await tester.runAsync(() async {
        pinButton.onPressed!();
        for (var attempt = 0; attempt < 50; attempt++) {
          if ((await journal.getById('a'))!.isPinned &&
              _events.any((event) => event.name == 'entry_pinned')) {
            return;
          }
          await Future<void>(() {});
        }
        fail('Pin button did not persist after 50 event-loop turns');
      });
      await tester.pump();

      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('Saved to Pinned'), findsOneWidget);
      expect(find.bySemanticsLabel('Unpin this entry'), findsOneWidget);
      expect(_events.map((e) => e.name), contains('entry_pinned'));

      await tester.runAsync(() async {
        expect((await journal.getById('a'))!.isPinned, isTrue);
      });

      // The receipt's dismiss timer runs on the real event loop inside
      // runAsync, so clear it before toggling again.
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
          .clearSnackBars();
      await tester.pumpAndSettle();

      final unpinButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('pin_entry_button')),
      );
      await tester.runAsync(() async {
        unpinButton.onPressed!();
        for (var attempt = 0; attempt < 50; attempt++) {
          if (!(await journal.getById('a'))!.isPinned &&
              _events.any((event) => event.name == 'entry_unpinned')) {
            return;
          }
          await Future<void>(() {});
        }
        fail('Unpin button did not persist after 50 event-loop turns');
      });
      await tester.pump();
      expect(find.text('Pin'), findsOneWidget);
      expect(find.text('Removed from Pinned'), findsOneWidget);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
          .clearSnackBars();
      await tester.pumpAndSettle();
      expect(_events.map((e) => e.name), contains('entry_unpinned'));
    });

    testWidgets('pinned screen shows pinned entries', (tester) async {
      late PinnedEvidenceStore pins;
      late Directory dir;
      final servicesDir = Directory.systemTemp.createTempSync(
        'vm_pinned_screen_services_',
      );
      await tester.runAsync(
        () => AppServices.resetForTest(
          journalPath: '${servicesDir.path}/journal.json',
          prefsPath: '${servicesDir.path}/prefs.json',
          skipRevenueCat: true,
        ),
      );
      await tester.runAsync(() async {
        final (journal, p, d) = await openStores();
        pins = p;
        dir = d;
        await journal.save(
          _entry(id: 'a', transcript: 'Pinned reflection about the launch'),
        );
        await journal.save(_entry(id: 'b'));
        await pins.setPinned('a', true, now: _base);
      });
      addTearDown(() async {
        await AppServices.disposeForTest();
        if (await dir.exists()) await dir.delete(recursive: true);
        if (await servicesDir.exists()) {
          await servicesDir.delete(recursive: true);
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PinnedEvidenceScreen(store: pins),
        ),
      );
      await pumpUntilFound(tester, find.byKey(const Key('pinned_entry_a')));

      expect(find.text('Pinned evidence'), findsOneWidget);
      expect(find.byKey(const Key('pinned_entry_a')), findsOneWidget);
      expect(find.byKey(const Key('pinned_entry_b')), findsNothing);
      expect(find.text('Pinned reflection about the launch'), findsOneWidget);
      expect(_events.map((e) => e.name), contains('pinned_evidence_opened'));
    });

    testWidgets('pinned screen empty state renders', (tester) async {
      late PinnedEvidenceStore pins;
      late Directory dir;
      await tester.runAsync(() async {
        final (_, p, d) = await openStores();
        pins = p;
        dir = d;
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PinnedEvidenceScreen(store: pins),
        ),
      );
      await pumpUntilFound(
        tester,
        find.byKey(const Key('pinned_evidence_empty')),
      );

      expect(find.byKey(const Key('pinned_evidence_empty')), findsOneWidget);
      expect(find.text('Nothing pinned yet'), findsOneWidget);
      expect(find.text('Pin entries you want to revisit.'), findsOneWidget);
    });

    test('pinning does not override memory scope', () async {
      final (journal, pins, dir) = await openStores();
      addTearDown(() => dir.deleteSync(recursive: true));
      MemoryScopePolicy.scope = MemoryScope.off;
      await journal.save(_entry(id: 'a'));
      await pins.setPinned('a', true);

      expect(MemoryScopePolicy.scope, MemoryScope.off);
      // Memory off still blocks all framing, pinned or not.
      final framing = _framingEngine.frame(
        [_rec(entryId: 'a', daysAgo: 0)],
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      expect(framing.frame.influenceLevel, MemoryInfluenceLevel.blocked);

      // The pinned copy gained no memory metadata.
      final pinned = await journal.getById('a');
      expect(pinned!.connectionApproved, isFalse);
      expect(pinned.treatAsNew, isTrue, reason: 'scope off saves as fresh');
    });

    test('pinning alone does not create high-authority evidence', () {
      // Evidence behind a pinned entry, with no user confirmation.
      final records = [
        _rec(entryId: 'p1', daysAgo: 6),
        _rec(entryId: 'p2', daysAgo: 3),
        _rec(entryId: 'p3', daysAgo: 0),
      ];
      final framing = _framingEngine.frame(
        records,
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      expect(
        framing.frame.influenceLevel,
        isNot(MemoryInfluenceLevel.highAuthority),
      );

      // Explicit user confirmation — not the pin — is the high-authority
      // path, exactly as before.
      final confirmed = _framingEngine.frame(
        [
          _rec(entryId: 'p1', daysAgo: 6),
          _rec(entryId: 'p2', daysAgo: 3, connectionApproved: true),
          _rec(entryId: 'p3', daysAgo: 0),
        ],
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      expect(
        confirmed.frame.influenceLevel,
        MemoryInfluenceLevel.highAuthority,
      );
    });
  });

  group('Privacy and copy guardrails', () {
    test('analytics contains no search text or private content', () {
      // Exhaustively check the typed surface: only whitelisted keys can
      // exist, and the new value sets are pinned.
      expect(
        ActivationFunnelAnalytics.allowedPropertyKeys.containsAll({
          'filter_type',
          'result_count_bucket',
        }),
        isTrue,
      );
      expect(ActivationFunnelAnalytics.allowedFilterTypeValues, {
        'keyword',
        'context_tag',
        'date',
        'memory_status',
        'exact_evidence',
        'pinned',
        'archived',
        'clear',
        'pack',
        'action_items',
        'entry_type',
        'surfacing',
        'preserved_original',
        'saved_details',
      });
      expect(ActivationFunnelAnalytics.allowedResultCountBucketValues, {
        'none',
        'few',
        'some',
        'many',
      });
      expect(ActivationFunnelAnalytics.resultCountBucket(0), 'none');
      expect(ActivationFunnelAnalytics.resultCountBucket(2), 'few');
      expect(ActivationFunnelAnalytics.resultCountBucket(7), 'some');
      expect(ActivationFunnelAnalytics.resultCountBucket(40), 'many');

      // A raw query has no parameter to travel in: free text passed to
      // any string parameter is dropped by the safe-id shape.
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.archiveSearchFilterUsed,
        filterType: _privatePhrase,
        source: _privatePhrase,
      );
      expect(_events.single.properties, isEmpty);
    });

    test('no VoiceMemory in consumer-facing copy', () {
      for (final copy in _consumerCopy()) {
        expect(
          copy.contains('VoiceMemory'),
          isFalse,
          reason: 'VoiceMemory leaked into: "$copy"',
        );
      }
    });

    test('banned-word sweep over all new consumer copy', () {
      const banned = [
        'always',
        'never',
        'proves',
        'definitely',
        'diagnosis',
        'diagnose',
        'therapy',
        'treatment',
        'fixed',
        'broken',
        'problem',
        'failure',
        'lazy',
        'weak',
        'must',
        'should',
        'surveillance',
        'spying',
        'tracking',
      ];
      for (final copy in _consumerCopy()) {
        final lower = copy.toLowerCase();
        for (final word in banned) {
          expect(
            RegExp('\\b$word\\b').hasMatch(lower),
            isFalse,
            reason: 'Banned word "$word" in: "$copy"',
          );
        }
      }
    });
  });
}
