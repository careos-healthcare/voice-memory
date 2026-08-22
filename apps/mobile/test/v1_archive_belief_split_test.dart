import 'dart:io';
import 'storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_belief_repository.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_belief_search_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_belief_view_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_storage_sandbox.dart';

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  String transcript = 'Saved moment transcript',
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: transcript,
    durationSeconds: 10,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 1,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'observation',
      repeatedSignal: 'signal',
    ),
  );
}

Future<ArchiveBeliefRepository> _repositoryFor(JournalStore store) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await openTestAppSqliteDatabase();
  return ArchiveBeliefRepository(
    journalStore: store,
    journalSqlite: JournalSqliteRepository(db),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await AppSqliteDatabase.resetForTest();
  });

  group('ArchiveBeliefRepository', () {
    late TestStorageSandbox sandbox;
    late JournalStore store;

    setUp(() {
      sandbox = TestStorageSandbox.create(prefix: 'vm_archive_repo_');
      store = JournalStore(file: File(sandbox.journalPath));
    });

    tearDown(() => sandbox.dispose());

    test('sorts entries newest first', () async {
      await store.save(_entry(id: 'old', createdAt: DateTime(2026)));
      await store.save(_entry(id: 'new', createdAt: DateTime(2026, 6)));

      final repository = await _repositoryFor(store);
      final result = await repository.loadSortedEntries();

      expect(result, isA<ArchiveBeliefLoadSuccess>());
      final entries = (result as ArchiveBeliefLoadSuccess).entries;
      expect(entries.map((e) => e.id).toList(), ['new', 'old']);
    });

    test('fetchPage returns twenty entries per page', () async {
      for (var index = 0; index < 25; index++) {
        await store.save(
          _entry(
            id: 'entry-$index',
            createdAt: DateTime(2026).add(Duration(minutes: index)),
          ),
        );
      }

      final repository = await _repositoryFor(store);
      await repository.syncJournalMirror();

      final firstPage = await repository.fetchPage(offset: 0);
      final secondPage = await repository.fetchPage(offset: 20);

      expect(firstPage.length, 20);
      expect(secondPage.length, 5);
      expect(firstPage.first.id, 'entry-24');
    });
  });

  group('ArchiveBeliefSearchState', () {
    final entries = [
      _entry(
        id: 'a',
        createdAt: DateTime(2026),
        transcript: 'Morning walk reflection',
      ),
      _entry(
        id: 'b',
        createdAt: DateTime(2026, 1, 2),
        transcript: 'Evening work stress',
      ),
    ];

    test('returns all entries when query is empty', () {
      final search = ArchiveBeliefSearchState();
      expect(search.filter(entries).length, 2);
    });

    test('filters case-insensitively by transcript substring', () {
      final search = ArchiveBeliefSearchState()..updateQuery('WORK');
      expect(search.filter(entries).map((e) => e.id).toList(), ['b']);
    });
  });

  group('ArchiveBeliefViewModel', () {
    late TestStorageSandbox sandbox;
    late JournalStore store;

    setUp(() {
      sandbox = TestStorageSandbox.create(prefix: 'vm_archive_vm_');
      store = JournalStore(file: File(sandbox.journalPath));
    });

    tearDown(() => sandbox.dispose());

    test('reload moves from loading to loaded with entries', () async {
      await store.save(_entry(id: 'e1', createdAt: DateTime(2026, 3)));
      final viewModel = ArchiveBeliefViewModel(
        repository: await _repositoryFor(store),
      );

      expect(viewModel.loadState, ArchiveBeliefLoadState.loading);
      await viewModel.reload();
      expect(viewModel.loadState, ArchiveBeliefLoadState.loaded);
      expect(viewModel.entries, isNotNull);
      expect(viewModel.entries!.length, 1);
    });

    test('shows search field only when more than one entry exists', () async {
      await store.save(_entry(id: 'e1', createdAt: DateTime(2026, 3)));
      final viewModel = ArchiveBeliefViewModel(
        repository: await _repositoryFor(store),
      );
      await viewModel.reload();
      expect(viewModel.showSearchField, isFalse);

      await store.save(_entry(id: 'e2', createdAt: DateTime(2026, 3, 2)));
      await viewModel.reload();
      expect(viewModel.showSearchField, isTrue);
    });

    test('visibleEntries reflects active search query', () async {
      await store.save(
        _entry(
          id: 'match',
          createdAt: DateTime(2026, 3),
          transcript: 'capacity boundary',
        ),
      );
      await store.save(
        _entry(
          id: 'other',
          createdAt: DateTime(2026, 3, 2),
          transcript: 'unrelated topic',
        ),
      );
      final viewModel = ArchiveBeliefViewModel(
        repository: await _repositoryFor(store),
      );
      await viewModel.reload();
      viewModel.search.updateQuery('capacity');

      expect(viewModel.visibleEntries.map((e) => e.id).toList(), ['match']);
      expect(viewModel.showsNoSearchResults, isFalse);
    });
  });

  group('ArchiveBeliefViewModel large archive', () {
    test(
      'filters five hundred entries without materializing eager children',
      () {
        final entries = List.generate(
          500,
          (index) => _entry(
            id: 'e$index',
            createdAt: DateTime(2026).add(Duration(minutes: index)),
            transcript: index.isEven
                ? 'even moment $index'
                : 'odd moment $index',
          ),
        );
        final search = ArchiveBeliefSearchState()..updateQuery('even');
        final filtered = search.filter(entries);
        expect(filtered.length, 250);
        expect(filtered.first.transcript, contains('even'));
      },
    );
  });
}