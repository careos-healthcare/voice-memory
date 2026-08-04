import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_search/archive_entry_search_engine.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_filters.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_query.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_result.dart';
import 'package:voicememory_mobile/features/collections/archive_collection.dart';
import 'package:voicememory_mobile/features/collections/archive_collection_store.dart';
import 'package:voicememory_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:voicememory_mobile/features/memory/memory_control_model.dart';
import 'package:voicememory_mobile/features/memory/memory_influence_level.dart';
import 'package:voicememory_mobile/features/memory/memory_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/memory/archive_retrieval_policy.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/screens/collection_detail_screen.dart';
import 'package:voicememory_mobile/screens/collections_screen.dart';
import 'package:voicememory_mobile/screens/entry_detail_screen.dart';
import 'package:voicememory_mobile/screens/pinned_evidence_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive_search/archive_filter_chips.dart';
import 'package:voicememory_mobile/widgets/archive_search/archive_search_result_card.dart';
import 'package:voicememory_mobile/widgets/collections/add_to_collection_sheet.dart';
import 'package:voicememory_mobile/widgets/collections/collection_chip.dart';

import 'support/widget_test_pump.dart';

const _engine = ArchiveEntrySearchEngine();
const _framingEngine = MemoryAuthorityFramingEngine();

final DateTime _base = DateTime(2026, 6, 12, 12);

const String _privateName = 'Secret acquisition plan';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

class _MemoryArchiveCollectionStore extends ArchiveCollectionStore {
  _MemoryArchiveCollectionStore(
    super.prefs,
    Iterable<ArchiveCollection> collections,
  ) : _collections = {
        for (final collection in collections) collection.id: collection,
      };

  final Map<String, ArchiveCollection> _collections;

  @override
  Future<List<ArchiveCollection>> loadAll() => SynchronousFuture(
    _collections.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  @override
  Future<ArchiveCollection?> getById(String id) =>
      SynchronousFuture(_collections[id]);

  @override
  Future<ArchiveCollection?> addEntry(
    String collectionId,
    String entryId, {
    DateTime? now,
  }) {
    final collection = _collections[collectionId];
    if (collection == null) return SynchronousFuture(null);
    final updated = collection.contains(entryId)
        ? collection
        : collection.copyWith(
            entryIds: [...collection.entryIds, entryId],
            updatedAt: now ?? DateTime.now(),
          );
    _collections[collectionId] = updated;
    return SynchronousFuture(updated);
  }

  @override
  Future<ArchiveCollection?> removeEntry(
    String collectionId,
    String entryId, {
    DateTime? now,
  }) {
    final collection = _collections[collectionId];
    if (collection == null) return SynchronousFuture(null);
    final updated = !collection.contains(entryId)
        ? collection
        : collection.copyWith(
            entryIds: collection.entryIds.where((id) => id != entryId).toList(),
            updatedAt: now ?? DateTime.now(),
          );
    _collections[collectionId] = updated;
    return SynchronousFuture(updated);
  }
}

class _MemoryJournalStore extends JournalStore {
  _MemoryJournalStore(this.entries) : super(file: File('/dev/null'));

  final List<JournalEntry> entries;

  @override
  Future<List<JournalEntry>> loadAll({bool includeDeleted = false}) =>
      SynchronousFuture(
        entries
            .where((entry) => includeDeleted || !entry.isDeleted)
            .toList(growable: false),
      );

  @override
  Future<JournalEntry?> getById(String id) {
    for (final entry in entries) {
      if (entry.id == id) return SynchronousFuture(entry);
    }
    return SynchronousFuture(null);
  }
}

JournalEntry _entry({
  required String id,
  String transcript = 'A regular reflection about the day',
  int daysAgo = 0,
}) => JournalEntry(
  id: id,
  createdAt: _base.subtract(Duration(days: daysAgo, hours: 1)),
  transcript: transcript,
  durationSeconds: 10,
  reflection: const Reflection(
    mood: 'calm',
    emotionalIntensity: 4,
    recurringThemes: ['work'],
    exactLanguagePattern: 'I need quiet',
    concreteObservation: 'You asked for quiet time.',
    repeatedSignal: 'Quiet mentioned twice.',
  ),
  syncStatus: SyncStatus.localOnly,
);

PressureCheckInRecord _rec({
  required String entryId,
  required int daysAgo,
  bool connectionApproved = false,
}) => PressureCheckInRecord(
  entryId: entryId,
  createdAt: _base.subtract(Duration(days: daysAgo, hours: 1)),
  optionId: 'could_not_stop',
  contextIds: const ['work'],
  connectionApproved: connectionApproved,
);

Future<(MobilePrefsStore, ArchiveCollectionStore, Directory)>
_openStores() async {
  final dir = Directory.systemTemp.createTempSync('vm_collections_');
  final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
  return (prefs, ArchiveCollectionStore.forPrefs(prefs), dir);
}

Future<ArchiveCollection> _waitForMembership({
  required ArchiveCollectionStore store,
  required String collectionId,
  required String entryId,
}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final collection = await store.getById(collectionId);
    if (collection != null && collection.entryIds.contains(entryId)) {
      return collection;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Timed out waiting for $entryId to join collection $collectionId');
}

Future<void> _waitForNoMembership({
  required ArchiveCollectionStore store,
  required String collectionId,
  required String entryId,
}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final collection = await store.getById(collectionId);
    if (collection != null && !collection.entryIds.contains(entryId)) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Timed out waiting for $entryId to leave collection $collectionId');
}

List<String> _consumerCopy() => [
  ArchiveCollectionsCopy.settingsTitle,
  ArchiveCollectionsCopy.settingsSubtitle,
  ArchiveCollectionsCopy.screenTitle,
  ArchiveCollectionsCopy.intro,
  ArchiveCollectionsCopy.emptyTitle,
  ArchiveCollectionsCopy.emptyHelper,
  ArchiveCollectionsCopy.createCollection,
  ArchiveCollectionsCopy.newCollection,
  ArchiveCollectionsCopy.nameLabel,
  ArchiveCollectionsCopy.addToCollection,
  ArchiveCollectionsCopy.removeFromCollection,
  ArchiveCollectionsCopy.renameCollection,
  ArchiveCollectionsCopy.deleteCollection,
  ArchiveCollectionsCopy.deleteConfirmTitle,
  ArchiveCollectionsCopy.deleteConfirmBody,
  ...ArchiveCollectionsCopy.namePlaceholders,
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

  group('Collection store', () {
    test('create collection persists across reopen', () async {
      final (prefs, store, dir) = await _openStores();
      addTearDown(() => dir.deleteSync(recursive: true));

      final created = await store.create('Work decisions', now: _base);
      expect(created!.name, 'Work decisions');
      expect(created.createdAt, _base);
      expect(created.entryIds, isEmpty);

      // Empty names are rejected.
      expect(await store.create('   '), isNull);

      final reopened = ArchiveCollectionStore.forPrefs(prefs);
      final all = await reopened.loadAll();
      expect(all.map((c) => c.name), ['Work decisions']);
    });

    test('rename collection persists', () async {
      final (prefs, store, dir) = await _openStores();
      addTearDown(() => dir.deleteSync(recursive: true));

      final created = await store.create('Business ideas', now: _base);
      final renamed = await store.rename(created!.id, 'Things to revisit');
      expect(renamed!.name, 'Things to revisit');

      final reloaded = await ArchiveCollectionStore.forPrefs(
        prefs,
      ).getById(created.id);
      expect(reloaded!.name, 'Things to revisit');
      expect(reloaded.createdAt, _base);
    });

    test('add entry to collection persists', () async {
      final (prefs, store, dir) = await _openStores();
      addTearDown(() => dir.deleteSync(recursive: true));

      final created = await store.create('Work decisions', now: _base);
      await store.addEntry(created!.id, 'entry-a');
      // Adding twice keeps one membership.
      await store.addEntry(created.id, 'entry-a');

      final reloaded = await ArchiveCollectionStore.forPrefs(
        prefs,
      ).getById(created.id);
      expect(reloaded!.entryIds, ['entry-a']);
    });

    test('remove entry from collection works', () async {
      final (_, store, dir) = await _openStores();
      addTearDown(() => dir.deleteSync(recursive: true));

      final created = await store.create('Work decisions', now: _base);
      await store.addEntry(created!.id, 'entry-a');
      await store.addEntry(created.id, 'entry-b');
      await store.removeEntry(created.id, 'entry-a');

      final reloaded = await store.getById(created.id);
      expect(reloaded!.entryIds, ['entry-b']);
    });

    test('one entry can belong to multiple collections', () async {
      final (_, store, dir) = await _openStores();
      addTearDown(() => dir.deleteSync(recursive: true));

      final first = await store.create('Work decisions', now: _base);
      final second = await store.create('Things to revisit', now: _base);
      await store.addEntry(first!.id, 'entry-a');
      await store.addEntry(second!.id, 'entry-a');

      final memberships = await store.collectionsForEntry('entry-a');
      expect(memberships.map((c) => c.id).toSet(), {first.id, second.id});
    });

    test('delete collection does not delete entries', () async {
      final (_, store, dir) = await _openStores();
      addTearDown(() => dir.deleteSync(recursive: true));
      final journal = await JournalStore.open('${dir.path}/entries.json');
      await journal.save(_entry(id: 'entry-a'));
      await journal.save(_entry(id: 'entry-b'));

      final created = await store.create('Work decisions', now: _base);
      await store.addEntry(created!.id, 'entry-a');
      await store.delete(created.id);

      expect(await store.getById(created.id), isNull);
      // The entries are untouched.
      final entries = await journal.loadAll();
      expect(entries.map((e) => e.id).toSet(), {'entry-a', 'entry-b'});
    });
  });

  group('Collections screens', () {
    testWidgets('collections screen renders collections', (tester) async {
      late _MemoryArchiveCollectionStore store;
      late Directory dir;
      await tester.runAsync(() async {
        final (prefs, backingStore, d) = await _openStores();
        dir = d;
        final created = await backingStore.create('Work decisions', now: _base);
        await backingStore.addEntry(created!.id, 'entry-a');
        store = _MemoryArchiveCollectionStore(
          prefs,
          await backingStore.loadAll(),
        );
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: CollectionsScreen(store: store),
        ),
      );
      await pumpUntilFound(tester, find.text('Work decisions'));

      expect(find.text('Collections'), findsOneWidget);
      expect(
        find.text('Group entries you want to revisit together.'),
        findsOneWidget,
      );
      expect(find.text('Work decisions'), findsOneWidget);
      expect(find.text('1 entry'), findsOneWidget);
      expect(find.text('Create collection'), findsOneWidget);
      expect(_events.map((e) => e.name), contains('collections_opened'));
    });

    testWidgets('collections empty state renders', (tester) async {
      late _MemoryArchiveCollectionStore store;
      late Directory dir;
      await tester.runAsync(() async {
        final (prefs, _, d) = await _openStores();
        store = _MemoryArchiveCollectionStore(prefs, const []);
        dir = d;
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: CollectionsScreen(store: store),
        ),
      );
      await pumpUntilFound(
        tester,
        find.byKey(const Key('collections_empty_state')),
      );

      expect(find.byKey(const Key('collections_empty_state')), findsOneWidget);
      expect(find.text('No collections yet'), findsOneWidget);
      expect(
        find.text(
          'Create a collection for decisions, ideas, or anything you want '
          'to keep together.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('collection detail lists only collection entries', (
      tester,
    ) async {
      late _MemoryArchiveCollectionStore store;
      late ArchiveCollectionStore backingStore;
      late JournalStore realJournal;
      late _MemoryJournalStore journal;
      late Directory dir;
      late String collectionId;
      await tester.runAsync(() async {
        final (prefs, openedStore, d) = await _openStores();
        backingStore = openedStore;
        dir = d;
        realJournal = await JournalStore.open('${dir.path}/entries.json');
        final inside = _entry(id: 'in', transcript: 'Inside the collection');
        final outside = _entry(id: 'out', transcript: 'Outside the collection');
        await realJournal.save(inside);
        await realJournal.save(outside);
        final created = await backingStore.create('Work decisions', now: _base);
        collectionId = created!.id;
        await backingStore.addEntry(collectionId, 'in');
        store = _MemoryArchiveCollectionStore(
          prefs,
          await backingStore.loadAll(),
        );
        journal = _MemoryJournalStore([inside, outside]);
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: CollectionDetailScreen(
            collectionId: collectionId,
            store: store,
            journalStore: journal,
          ),
        ),
      );
      await pumpUntilFound(tester, find.text('Inside the collection'));

      expect(find.text('Work decisions'), findsOneWidget);
      expect(find.text('Inside the collection'), findsOneWidget);
      expect(find.text('Outside the collection'), findsNothing);

      // Remove the entry from the collection — the entry survives.
      await tester.tap(find.byKey(const Key('collection_remove_in')));
      await tester.runAsync(() async {
        await backingStore.removeEntry(collectionId, 'in');
        await _waitForNoMembership(
          store: backingStore,
          collectionId: collectionId,
          entryId: 'in',
        );
      });
      await pumpUntilAbsent(tester, find.text('Inside the collection'));
      expect(find.text('Inside the collection'), findsNothing);
      late JournalEntry? persistedEntry;
      await tester.runAsync(() async {
        persistedEntry = await realJournal.getById('in');
      });
      expect(persistedEntry?.transcript, 'Inside the collection');
      expect((await store.getById(collectionId))!.entryIds, isEmpty);
      expect(_events.map((e) => e.name), contains('collection_entry_removed'));
    });

    testWidgets('Add to collection works from entry detail', (tester) async {
      late Directory dir;
      late ArchiveCollection collection;
      late _MemoryArchiveCollectionStore sheetStore;
      await tester.runAsync(() async {
        dir = Directory.systemTemp.createTempSync('vm_col_detail_');
        await AppServices.resetForTest(
          journalPath: '${dir.path}/entries.json',
          prefsPath: '${dir.path}/prefs.json',
          skipRevenueCat: true,
        );
        await AppServices.instance.journalStore.save(_entry(id: 'a'));
        final backingStore = ArchiveCollectionStore.instance();
        final created = await backingStore.create('Work decisions', now: _base);
        collection = created!;
        sheetStore = _MemoryArchiveCollectionStore(AppServices.instance.prefs, [
          collection,
        ]);
      });
      addTearDown(() async {
        await AppServices.disposeForTest();
        dir.deleteSync(recursive: true);
      });

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const EntryDetailScreen(entryId: 'a'),
        ),
      );
      await pumpUntilFound(tester, find.text('Advanced entry details'));

      await tester.tap(find.text('Advanced entry details'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('entry_add_to_collection')), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.ensureVisible(
        find.byKey(const Key('entry_add_to_collection')),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('entry_add_to_collection')));
      await pumpUntilFound(tester, find.byType(AddToCollectionSheet));
      Navigator.of(tester.element(find.byType(AddToCollectionSheet))).pop();
      await pumpUntilAbsent(tester, find.byType(AddToCollectionSheet));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AddToCollectionSheet(store: sheetStore, entryId: 'a'),
          ),
        ),
      );

      expect(find.byType(AddToCollectionSheet), findsOneWidget);
      await pumpUntilFound(
        tester,
        find.byKey(Key('add_to_collection_${collection.id}')),
      );

      expect(
        find.byKey(Key('add_to_collection_${collection.id}')),
        findsOneWidget,
      );
      final tile = tester.widget<CheckboxListTile>(
        find.byKey(Key('add_to_collection_${collection.id}')),
      );
      expect(tile.value, isFalse);
      tile.onChanged!(true);

      late ArchiveCollection updatedCollection;
      await tester.runAsync(() async {
        await ArchiveCollectionStore.instance().addEntry(collection.id, 'a');
        updatedCollection = await _waitForMembership(
          store: ArchiveCollectionStore.instance(),
          collectionId: collection.id,
          entryId: 'a',
        );
      });
      expect(updatedCollection.entryIds, ['a']);
      await pumpUntil(
        tester,
        () =>
            tester
                .widget<CheckboxListTile>(
                  find.byKey(Key('add_to_collection_${collection.id}')),
                )
                .value ==
            true,
        reason: 'collection membership checkbox to become checked',
      );
      expect(_events.map((e) => e.name), contains('collection_entry_added'));
      // The sheet reloaded with the membership ticked.
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(Key('add_to_collection_${collection.id}')),
            )
            .value,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Add to collection works from pinned evidence', (tester) async {
      late Directory dir;
      late ArchiveCollection collection;
      late _MemoryArchiveCollectionStore sheetStore;
      await tester.runAsync(() async {
        dir = Directory.systemTemp.createTempSync('vm_col_pinned_');
        await AppServices.resetForTest(
          journalPath: '${dir.path}/entries.json',
          skipRevenueCat: true,
        );
        final journal = AppServices.instance.journalStore;
        await journal.save(_entry(id: 'a'));
        final pinned = JournalEntry(
          id: 'a',
          createdAt: _base,
          transcript: 'A regular reflection about the day',
          durationSeconds: 10,
          reflection: _entry(id: 'a').reflection,
          syncStatus: SyncStatus.localOnly,
          isPinned: true,
          pinnedAt: _base,
        );
        await journal.save(pinned);
        final backingStore = ArchiveCollectionStore.instance();
        final created = await backingStore.create(
          'Things to revisit',
          now: _base,
        );
        collection = created!;
        sheetStore = _MemoryArchiveCollectionStore(AppServices.instance.prefs, [
          collection,
        ]);
      });
      addTearDown(() async {
        await AppServices.disposeForTest();
        dir.deleteSync(recursive: true);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const PinnedEvidenceScreen(),
        ),
      );
      await pumpUntilFound(
        tester,
        find.byKey(const Key('pinned_add_to_collection_a')),
      );

      expect(
        find.byKey(const Key('pinned_add_to_collection_a')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('pinned_add_to_collection_a')));
      await pumpUntilFound(tester, find.byType(AddToCollectionSheet));
      Navigator.of(tester.element(find.byType(AddToCollectionSheet))).pop();
      await pumpUntilAbsent(tester, find.byType(AddToCollectionSheet));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AddToCollectionSheet(
              store: sheetStore,
              entryId: 'a',
              source: 'pinned_screen',
            ),
          ),
        ),
      );
      await pumpUntilFound(
        tester,
        find.byKey(Key('add_to_collection_${collection.id}')),
      );

      final tile = tester.widget<CheckboxListTile>(
        find.byKey(Key('add_to_collection_${collection.id}')),
      );
      tile.onChanged!(true);

      late ArchiveCollection updatedCollection;
      await tester.runAsync(() async {
        await ArchiveCollectionStore.instance().addEntry(collection.id, 'a');
        updatedCollection = await _waitForMembership(
          store: ArchiveCollectionStore.instance(),
          collectionId: collection.id,
          entryId: 'a',
        );
      });
      expect(updatedCollection.entryIds, ['a']);
      await pumpUntil(
        tester,
        () =>
            tester
                .widget<CheckboxListTile>(
                  find.byKey(Key('add_to_collection_${collection.id}')),
                )
                .value ==
            true,
        reason: 'collection membership checkbox to become checked',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('Search integration', () {
    test('collection filter works in Archive Search 2.0', () {
      final entries = [_entry(id: 'in'), _entry(id: 'out')];
      final collections = [
        ArchiveCollection(
          id: 'col1',
          name: 'Work decisions',
          createdAt: _base,
          updatedAt: _base,
          entryIds: const ['in'],
        ),
      ];
      final results = _engine.search(
        entries: entries,
        collections: collections,
        query: const ArchiveEntrySearchQuery(collectionId: 'col1'),
        now: _base,
      );
      expect(results.map((r) => r.entry.id), ['in']);
      expect(results.single.collectionNames, ['Work decisions']);

      // Clearing filters drops the collection filter too.
      const query = ArchiveEntrySearchQuery(collectionId: 'col1');
      expect(query.hasActiveFilters, isTrue);
      expect(query.clearedFilters().hasActiveFilters, isFalse);
    });

    testWidgets('collection filter chip fires fixed event with no name', (
      tester,
    ) async {
      var query = const ArchiveEntrySearchQuery();
      final collections = [
        ArchiveCollection(
          id: 'col1',
          name: _privateName,
          createdAt: _base,
          updatedAt: _base,
        ),
      ];
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => ArchiveFilterChips(
                  query: query,
                  availableCollections: collections,
                  onChanged: (next) => setState(() => query = next),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('archive_filter_collection_col1')));
      await tester.pump();
      expect(query.collectionId, 'col1');

      final filterEvents = _events
          .where((e) => e.name == 'collection_filter_used')
          .toList();
      expect(filterEvents.length, 1);
      expect(filterEvents.single.properties, isEmpty);

      final payload = _events.map((e) => '${e.name} ${e.properties}').join();
      expect(payload.contains('Secret'), isFalse);
      expect(payload.contains('acquisition'), isFalse);
    });

    testWidgets('collection chips render safely on result cards', (
      tester,
    ) async {
      late Directory dir;
      await tester.runAsync(() async {
        dir = Directory.systemTemp.createTempSync('vm_collection_card_');
        await AppServices.resetForTest(
          journalPath: '${dir.path}/entries.json',
          prefsPath: '${dir.path}/prefs.json',
          skipRevenueCat: true,
        );
      });
      addTearDown(() async {
        await AppServices.disposeForTest();
        dir.deleteSync(recursive: true);
      });

      final result = ArchiveEntrySearchResult(
        entry: _entry(id: 'a', transcript: 'Planning the product launch'),
        timeBucket: ArchiveDateFilter.today,
        collectionNames: const ['Work decisions'],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ArchiveSearchResultCard(result: result)),
        ),
      );
      expect(find.byType(CollectionChip), findsOneWidget);
      expect(find.text('Work decisions'), findsOneWidget);
      // No analytics fired from rendering.
      expect(_events, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('Memory guardrails', () {
    test('collection membership does not create authority', () {
      final records = [
        _rec(entryId: 'a', daysAgo: 6),
        _rec(entryId: 'b', daysAgo: 3),
        _rec(entryId: 'c', daysAgo: 0),
      ];
      final withoutMembership = _framingEngine.frame(
        records,
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );

      // Membership lives entirely outside the framing engine's inputs —
      // an entry in five collections frames exactly the same.
      MemoryAuthorityFrameLog.resetForTest();
      final withMembership = _framingEngine.frame(
        records,
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      expect(
        withMembership.frame.influenceLevel,
        withoutMembership.frame.influenceLevel,
      );
      expect(
        withMembership.frame.influenceLevel,
        isNot(MemoryInfluenceLevel.highAuthority),
      );

      // Explicit user confirmation — not membership — remains the only
      // high-authority path.
      final confirmed = _framingEngine.frame(
        [
          _rec(entryId: 'a', daysAgo: 6),
          _rec(entryId: 'b', daysAgo: 3, connectionApproved: true),
          _rec(entryId: 'c', daysAgo: 0),
        ],
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      expect(
        confirmed.frame.influenceLevel,
        MemoryInfluenceLevel.highAuthority,
      );
    });

    test('collection membership does not override memory scope', () async {
      final (_, store, dir) = await _openStores();
      addTearDown(() => dir.deleteSync(recursive: true));

      MemoryScopePolicy.scope = MemoryScope.off;
      final created = await store.create('Work decisions', now: _base);
      await store.addEntry(created!.id, 'a');

      expect(MemoryScopePolicy.scope, MemoryScope.off);
      final framing = _framingEngine.frame(
        [_rec(entryId: 'a', daysAgo: 0)],
        now: _base,
        cardType: MemoryCardType.threadReturn,
      );
      expect(framing.frame.influenceLevel, MemoryInfluenceLevel.blocked);
    });

    test('collection membership does not make stale or superseded '
        'evidence current', () {
      final entries = [_entry(id: 'old', daysAgo: 40)];
      final collections = [
        ArchiveCollection(
          id: 'col1',
          name: 'Things to revisit',
          createdAt: _base,
          updatedAt: _base,
          entryIds: const ['old'],
        ),
      ];
      final results = _engine.search(
        entries: entries,
        collections: collections,
        query: const ArchiveEntrySearchQuery(collectionId: 'col1'),
        now: _base,
      );
      expect(
        results.single.memoryStatus,
        ArchiveMemoryStatus.mayBeStale,
        reason: 'membership is organization only — status is unchanged',
      );
    });
  });

  group('Privacy and copy guardrails', () {
    test('collection name is never logged in analytics', () async {
      final (_, store, dir) = await _openStores();
      addTearDown(() => dir.deleteSync(recursive: true));

      // Exercise the full lifecycle with a private name.
      final created = await store.create(_privateName, now: _base);
      await store.addEntry(created!.id, 'entry-a');
      await store.rename(created.id, '$_privateName v2');
      await store.removeEntry(created.id, 'entry-a');
      await store.delete(created.id);

      // The store itself fires nothing; UI events carry no name. Fire
      // each event the UI uses and confirm no payload can carry text.
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.collectionCreated,
        source: 'collections',
      );
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.collectionEntryAdded,
        source: 'entry_detail',
      );
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.collectionDeleted,
        entryCount: 1,
      );
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.collectionsOpened,
        collectionCountBucket: 'few',
      );

      final payload = _events.map((e) => '${e.name} ${e.properties}').join();
      expect(payload.contains('Secret'), isFalse);
      expect(payload.contains('acquisition'), isFalse);
      expect(payload.toLowerCase().contains('plan'), isFalse);
    });

    test('analytics payload contains no private content', () {
      // Free text passed into any string parameter is dropped by the
      // safe-id whitelists.
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.collectionCreated,
        source: _privateName,
        collectionCountBucket: _privateName,
        filterType: _privateName,
      );
      expect(_events.single.properties, isEmpty);

      expect(
        ActivationFunnelAnalytics.allowedPropertyKeys.contains(
          'collection_count_bucket',
        ),
        isTrue,
      );
      expect(ActivationFunnelAnalytics.allowedCollectionCountBucketValues, {
        'none',
        'few',
        'some',
        'many',
      });
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
