import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../features/activation/capture_context_tags.dart';
import '../features/journal/infrastructure/journal_save_interceptor_pipeline.dart';
import '../features/journal/migration/saved_moment_legacy_adapter.dart';
import '../core/sync/journal_sync_conflict_resolver.dart';
import '../models/journal_entry.dart';
import '../models/sync_status.dart';
import 'encrypted_json_file_store.dart';
import 'private_data_encryption_key_store.dart';
import 'secure_storage.dart';

typedef JournalPostPersistHook =
    Future<void> Function(List<JournalEntry> persistedEntries);
typedef JournalSyncDeviceIdProvider = Future<String> Function();
typedef JournalStoreClock = DateTime Function();

/// Durable journal file on device — encrypted at rest when [encryptAtRest] is enabled.
///
/// Every store is bound to exactly one [ownerArchiveId]. There is no global
/// journal and no default owner: a caller that cannot name an archive cannot
/// open a store, and a store never returns an entry belonging to a different
/// archive even if one is present in its file.
class JournalStore {
  JournalStore({
    required this.file,
    required this.ownerArchiveId,
    EncryptedJsonFileStore? encryptedStore,
    File? plaintextLegacyFile,
    this._encryptAtRest = false,
    Object? cognitiveAnalyzer,
    JournalSaveInterceptorPipeline? saveInterceptorPipeline,
    JournalSyncDeviceIdProvider? syncDeviceIdProvider,
    JournalStoreClock? clock,
  }) : assert(
         ownerArchiveId != '',
         'A journal store must be bound to an archive.',
       ),
       _encrypted = encryptedStore,
       _plaintextLegacy = plaintextLegacyFile,
       _saveInterceptorPipeline =
           saveInterceptorPipeline ?? JournalSaveInterceptorPipeline.empty(),
       _syncDeviceIdProvider =
           syncDeviceIdProvider ?? _defaultSyncDeviceIdProvider,
       _clock = clock ?? DateTime.now;

  /// Primary on-disk file — encrypted envelope when [encryptAtRest] is true.
  final File file;

  final EncryptedJsonFileStore? _encrypted;
  final File? _plaintextLegacy;
  final bool _encryptAtRest;
  final JournalSyncDeviceIdProvider _syncDeviceIdProvider;
  final JournalStoreClock _clock;
  final String ownerArchiveId;
  JournalSaveInterceptorPipeline _saveInterceptorPipeline;
  JournalPostPersistHook? _postPersistHook;

  List<JournalEntry>? _cache;
  final StreamController<List<JournalEntry>> _changes =
      StreamController<List<JournalEntry>>.broadcast();

  Stream<List<JournalEntry>> watchAll() async* {
    yield List<JournalEntry>.unmodifiable(await loadAll());
    yield* _changes.stream;
  }

  void configureSaveInterceptorPipeline(
    JournalSaveInterceptorPipeline pipeline,
  ) {
    _saveInterceptorPipeline = pipeline;
  }

  void configurePostPersistHook(JournalPostPersistHook? hook) {
    _postPersistHook = hook;
  }

  static String encryptedPathFor(String legacyJsonPath) {
    if (legacyJsonPath.endsWith('.json')) {
      return legacyJsonPath.replaceFirst(RegExp(r'\.json$'), '.enc');
    }
    return '$legacyJsonPath.enc';
  }

  static Future<JournalStore> open(
    String filePath, {
    required String ownerArchiveId,
    PrivateDataEncryptionKeyStore? keyStore,
    bool encryptAtRest = true,
    SecureStorageService? secureStorage,
    Object? cognitiveAnalyzer,
    JournalSaveInterceptorPipeline? saveInterceptorPipeline,
    JournalSyncDeviceIdProvider? syncDeviceIdProvider,
    JournalStoreClock? clock,
  }) async {
    final legacyFile = File(filePath);
    if (!await legacyFile.parent.exists()) {
      await legacyFile.parent.create(recursive: true);
    }

    if (!encryptAtRest) {
      if (!await legacyFile.exists()) {
        await legacyFile.writeAsString('[]');
      }
      final store = JournalStore(
        file: legacyFile,
        encryptAtRest: false,
        cognitiveAnalyzer: cognitiveAnalyzer,
        saveInterceptorPipeline: saveInterceptorPipeline,
        syncDeviceIdProvider: syncDeviceIdProvider,
        clock: clock,
        ownerArchiveId: ownerArchiveId,
      );
      store._cache = store._decodeEntries(await legacyFile.readAsString());
      return store;
    }

    final resolvedKeyStore = keyStore ?? _defaultKeyStore(secureStorage);
    final encryptedFile = File(encryptedPathFor(filePath));
    final encryptedStore = EncryptedJsonFileStore(
      file: encryptedFile,
      keyStore: resolvedKeyStore,
    );

    await encryptedStore.ensureKey();
    await encryptedStore.migrateFromPlaintextFile(legacyFile);

    if (!await encryptedFile.exists()) {
      await encryptedStore.writeJson([]);
    }

    final store = JournalStore(
      file: encryptedFile,
      encryptedStore: encryptedStore,
      plaintextLegacyFile: legacyFile,
      encryptAtRest: true,
      cognitiveAnalyzer: cognitiveAnalyzer,
      saveInterceptorPipeline: saveInterceptorPipeline,
      syncDeviceIdProvider: syncDeviceIdProvider,
      clock: clock,
      ownerArchiveId: ownerArchiveId,
    );
    store._cache = await store._loadEntriesFromEncrypted();
    return store;
  }

  Future<List<JournalEntry>> loadAll({bool includeDeleted = false}) async {
    if (_encryptAtRest && _encrypted != null) {
      _cache = await _loadEntriesFromEncrypted();
      return _visibleEntries(_cache!, includeDeleted: includeDeleted);
    }
    return loadAllSync(includeDeleted: includeDeleted);
  }

  /// Same as [loadAll] but synchronous — uses the in-memory cache after [open].
  List<JournalEntry> loadAllSync({bool includeDeleted = false}) {
    if (_cache != null) {
      return _visibleEntries(_cache!, includeDeleted: includeDeleted);
    }

    final source = _encryptAtRest ? file : (_plaintextLegacy ?? file);
    if (!source.existsSync()) return [];
    final raw = source.readAsStringSync();
    if (raw.trim().isEmpty) return [];
    _cache = _decodeEntries(raw);
    return _visibleEntries(_cache!, includeDeleted: includeDeleted);
  }

  Future<void> clearAll() async {
    await _writeAll(const []);
  }

  Future<void> save(
    JournalEntry entry, {
    String first25Source = 'journal_save',
  }) async {
    if (entry.ownerArchiveId != ownerArchiveId &&
        entry.ownerArchiveId !=
            SavedMomentLegacyAdapter.legacyUnscopedArchiveId) {
      throw StateError(
        'Saved moment ${entry.id} belongs to ${entry.ownerArchiveId} and '
        'cannot be written into $ownerArchiveId.',
      );
    }
    final all = await loadAll(includeDeleted: true);
    final isNew = !all.any((e) => e.id == entry.id);
    var toPersist = entry;
    if (entry.localCaptureContext != null &&
        toPersist.localCaptureContext == null) {
      toPersist = toPersist.copyWith(
        localCaptureContext: entry.localCaptureContext,
      );
    }
    toPersist = JournalSyncConflictResolver.stampLocalWrite(
      entry: toPersist,
      previous: isNew ? null : all.firstWhere((item) => item.id == entry.id),
      deviceId: await _syncDeviceIdProvider(),
      updatedAt: _clock(),
    );
    toPersist = toPersist.copyWith(
      ownerArchiveId: ownerArchiveId,
      updatedAt: _clock().toUtc(),
      schemaVersion: JournalEntry.currentSchemaVersion,
    );
    final next = [toPersist, ...all.where((e) => e.id != entry.id)];
    await _writeAll(next);
    await _saveInterceptorPipeline.execute(toPersist);
  }

  Future<void> update(JournalEntry entry) async => save(entry);

  Future<void> updateCaptureContextTag(String id, {String? tagId}) async {
    final entry = await getById(id);
    if (entry == null) return;
    await save(CaptureContextTags.updateTag(entry, tagId));
  }

  Future<List<JournalEntry>> loadEligible() async {
    final all = await loadAll(includeDeleted: true);
    return all
        .where(
          (e) =>
              e.transcript.trim().isNotEmpty &&
              !e.transcript.startsWith('[draft]'),
        )
        .toList();
  }

  Future<int> reflectionCount() async => (await loadEligible()).length;

  Future<List<JournalEntry>> pendingSyncQueue() async {
    final all = await loadAll(includeDeleted: true);
    return all
        .where(
          (e) =>
              e.captureContextTag != 'memory_graph_voice_conversation' &&
              (e.syncStatus == SyncStatus.pendingUpload ||
                  e.syncStatus == SyncStatus.localOnly),
        )
        .toList();
  }

  Future<void> markSynced(String id) async {
    final all = await loadAll(includeDeleted: true);
    var found = false;
    final next = all.map((entry) {
      if (entry.id != id) return entry;
      found = true;
      return entry.copyWith(syncStatus: SyncStatus.synced);
    }).toList();
    if (found) await _writeAll(next);
  }

  Future<JournalMergeResult> mergeRemote(
    List<JournalEntry> remote, {
    String? localDeviceId,
  }) async {
    final deviceId = localDeviceId ?? await _syncDeviceIdProvider();
    final local = await loadAll(includeDeleted: true);
    final result = JournalSyncConflictResolver.merge(
      localEntries: local,
      remoteEntries: remote,
      localDeviceId: deviceId,
    );
    await _writeAll(result.entries);
    return result;
  }

  Future<void> delete(String id) async {
    final all = await loadAll(includeDeleted: true);
    final existing = all.where((entry) => entry.id == id).firstOrNull;
    if (existing == null || existing.isDeleted) return;
    final deletedAt = _clock().toUtc();
    final tombstone = JournalSyncConflictResolver.stampLocalWrite(
      entry: existing.copyWith(deletedAt: deletedAt, updatedAt: deletedAt),
      previous: existing,
      deviceId: await _syncDeviceIdProvider(),
      updatedAt: deletedAt,
    );
    await _writeAll([tombstone, ...all.where((entry) => entry.id != id)]);
  }

  Future<JournalEntry?> getById(String id) async {
    final all = await loadAll();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<String> exportJson() async {
    final all = await loadAll();
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(all.map((e) => e.toJson()).toList());
  }

  /// Replaces the on-device journal — local backup restore only.
  ///
  /// A restore always lands in the archive doing the restoring; a backup file
  /// cannot carry another account's ownership into this archive.
  Future<void> replaceAll(List<JournalEntry> entries) async {
    final next =
        entries
            .map((entry) => entry.copyWith(ownerArchiveId: ownerArchiveId))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _writeAll(next);
  }

  Future<void> _writeAll(List<JournalEntry> entries) async {
    final owned = entries
        .where((entry) => entry.ownerArchiveId == ownerArchiveId)
        .toList(growable: false);
    if (owned.length != entries.length) {
      throw StateError(
        'Refusing to write an entry owned by another archive into '
        '$ownerArchiveId.',
      );
    }
    // Rows belonging to another archive are retained byte-for-byte. They are
    // never readable here, but this store must not destroy another owner's
    // data just because it happens to share a file after a partial migration.
    final foreign = (_cache ?? const <JournalEntry>[])
        .where((entry) => entry.ownerArchiveId != ownerArchiveId)
        .toList(growable: false);
    final combined = [...owned, ...foreign];
    final encoded = combined.map((e) => e.toJson()).toList();
    if (_encrypted != null) {
      await _encrypted.writeJson(encoded);
    } else {
      await file.writeAsString(jsonEncode(encoded));
    }
    _cache = combined;
    _emitChanges();
    final hook = _postPersistHook;
    if (hook != null) {
      try {
        await hook(List<JournalEntry>.unmodifiable(owned));
      } on Object {
        // Derived indexes are best-effort and never roll back a durable write.
      }
    }
  }

  void _emitChanges() {
    if (_changes.isClosed) return;
    _changes.add(
      List<JournalEntry>.unmodifiable(
        _visibleEntries(_cache ?? const [], includeDeleted: false),
      ),
    );
  }

  Future<List<JournalEntry>> _loadEntriesFromEncrypted() async {
    if (_encrypted == null) return [];
    final decoded = await _encrypted.readJson();
    if (decoded == null) return [];
    return _decodeEntries(jsonEncode(decoded));
  }

  static Future<String> _defaultSyncDeviceIdProvider() async => 'local-device';

  List<JournalEntry> _decodeEntries(String raw) {
    if (raw.trim().isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final entries = list
        .map(
          (e) => JournalEntry.fromJson(
            SavedMomentLegacyAdapter.migrate(
              Map<String, dynamic>.from(e as Map),
              ownerArchiveId: ownerArchiveId,
              migratedAt: _clock().toUtc(),
            ),
          ),
        )
        .toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  /// Owner-constrained projection. Anything stamped with another archive is
  /// treated as absent rather than merely hidden, so no read path — Archive,
  /// search, Changes, export, sync queue or analysis — can observe it.
  List<JournalEntry> _visibleEntries(
    Iterable<JournalEntry> entries, {
    required bool includeDeleted,
  }) => List<JournalEntry>.from(
    entries.where(
      (entry) =>
          entry.ownerArchiveId == ownerArchiveId &&
          (includeDeleted || !entry.isDeleted),
    ),
  );

  static PrivateDataEncryptionKeyStore _defaultKeyStore(
    SecureStorageService? secureStorage,
  ) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return InMemoryPrivateDataEncryptionKeyStore();
    }
    return SecurePrivateDataEncryptionKeyStore(secure: secureStorage);
  }
}
