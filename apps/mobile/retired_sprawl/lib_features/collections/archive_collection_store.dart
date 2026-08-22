import 'package:archiveme_mobile/config/creator_demo_mode.dart';
import 'package:archiveme_mobile/features/collections/archive_collection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local store for Collections, backed by the same on-device prefs file
/// as other ArchiveMe local state — no backend dependency.
///
/// Organization only: this store holds group names and entry-id lists.
/// It never reads or writes entries, memory records, or scope state, so
/// membership can never change what the archive remembers or claims.
class ArchiveCollectionStore {
  ArchiveCollectionStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'archiveCollections';

  static int _idCounter = 0;

  static ArchiveCollectionStore instance() =>
      ArchiveCollectionStore(AppServices.instance.prefs);

  static ArchiveCollectionStore forPrefs(MobilePrefsStore prefs) =>
      ArchiveCollectionStore(prefs);

  /// All collections, most recently updated first.
  Future<List<ArchiveCollection>> loadAll() async {
    // Creator demo mode: the real local store is never read.
    if (CreatorDemoMode.isActive) return const [];
    final raw = await _prefs.readMap(_key);
    if (raw == null) return [];
    final collections = raw.values
        .whereType<Map>()
        .map((m) => ArchiveCollection.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    collections.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return collections;
  }

  Future<ArchiveCollection?> getById(String id) async {
    final all = await loadAll();
    for (final collection in all) {
      if (collection.id == id) return collection;
    }
    return null;
  }

  /// Collections that contain [entryId], most recently updated first.
  Future<List<ArchiveCollection>> collectionsForEntry(String entryId) async {
    final all = await loadAll();
    return all.where((c) => c.contains(entryId)).toList();
  }

  /// Creates a collection. Returns null when the trimmed name is empty.
  Future<ArchiveCollection?> create(String name, {DateTime? now}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (CreatorDemoMode.isActive) return null;
    final at = now ?? DateTime.now();
    final collection = ArchiveCollection(
      id: 'col_${at.microsecondsSinceEpoch}_${_idCounter++}',
      name: trimmed,
      createdAt: at,
      updatedAt: at,
    );
    await _put(collection);
    return collection;
  }

  /// Renames a collection. Empty names are ignored.
  Future<ArchiveCollection?> rename(
    String id,
    String name, {
    DateTime? now,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    return _update(
      id,
      (c) => c.copyWith(name: trimmed, updatedAt: now ?? DateTime.now()),
    );
  }

  /// Deletes the collection only — the entries inside it are untouched.
  Future<void> delete(String id) async {
    if (CreatorDemoMode.isActive) return;
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      map.remove(id);
      return map;
    });
  }

  /// Adds [entryId] to the collection. No-op when already a member.
  Future<ArchiveCollection?> addEntry(
    String collectionId,
    String entryId, {
    DateTime? now,
  }) => _update(collectionId, (c) {
    if (c.contains(entryId)) return c;
    return c.copyWith(
      entryIds: [...c.entryIds, entryId],
      updatedAt: now ?? DateTime.now(),
    );
  });

  /// Removes [entryId] from the collection — the entry itself stays in
  /// the archive.
  Future<ArchiveCollection?> removeEntry(
    String collectionId,
    String entryId, {
    DateTime? now,
  }) => _update(collectionId, (c) {
    if (!c.contains(entryId)) return c;
    return c.copyWith(
      entryIds: c.entryIds.where((id) => id != entryId).toList(),
      updatedAt: now ?? DateTime.now(),
    );
  });

  Future<ArchiveCollection?> _update(
    String id,
    ArchiveCollection Function(ArchiveCollection) transform,
  ) async {
    if (CreatorDemoMode.isActive) return null;
    ArchiveCollection? result;
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      final raw = map[id];
      if (raw is! Map) return map;
      final updated = transform(
        ArchiveCollection.fromJson(Map<String, dynamic>.from(raw)),
      );
      result = updated;
      map[id] = updated.toJson();
      return map;
    });
    return result;
  }

  Future<void> _put(ArchiveCollection collection) async {
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      map[collection.id] = collection.toJson();
      return map;
    });
  }
}