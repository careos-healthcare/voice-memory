import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/config/archive_me_demo_state.dart';
import 'package:archiveme_mobile/config/creator_demo_mode.dart';
import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/services/cognitive_analyzer.dart';
import 'package:archiveme_mobile/features/demo/archive_me_demo_archive.dart';
import 'package:archiveme_mobile/features/first25/first25_journal_hooks.dart';
import 'package:archiveme_mobile/features/journal/infrastructure/journal_save_interceptor_pipeline.dart';
import 'package:archiveme_mobile/features/memory/entry_save_coordinator.dart';
import 'package:archiveme_mobile/features/referral/invite_funnel_metrics.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_milestone_coordinator.dart';
import 'package:archiveme_mobile/services/journal_ownership_guard.dart' show JournalOwnershipGuard;
import 'package:archiveme_mobile/storage/encrypted_json_file_store.dart';
import 'package:archiveme_mobile/storage/journal_entry_decoder.dart';
import 'package:archiveme_mobile/storage/private_data_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';
import 'package:archiveme_mobile/sync/journal_conflict_resolver.dart';

/// Durable journal file on device — encrypted at rest when [encryptAtRest] is enabled.
class JournalStore {
  JournalStore({
    required this.file,
    EncryptedJsonFileStore? encryptedStore,
    File? plaintextLegacyFile,
    this._encryptAtRest = false,
    CognitiveAnalyzer? cognitiveAnalyzer,
    JournalSaveInterceptorPipeline? saveInterceptorPipeline,
  }) : _encrypted = encryptedStore,
       _plaintextLegacy = plaintextLegacyFile,
       _cognitiveAnalyzer = cognitiveAnalyzer ?? const CognitiveAnalyzer(),
       _saveInterceptorPipeline =
           saveInterceptorPipeline ?? JournalSaveInterceptorPipeline.empty();

  /// Primary on-disk file — encrypted envelope when [encryptAtRest] is true.
  final File file;

  final EncryptedJsonFileStore? _encrypted;
  final File? _plaintextLegacy;
  final bool _encryptAtRest;
  final CognitiveAnalyzer _cognitiveAnalyzer;
  JournalSaveInterceptorPipeline _saveInterceptorPipeline;

  List<JournalEntry>? _cache;
  final List<JournalDecodeQuarantined> _lastLoadQuarantine = [];

  /// Records quarantined during the most recent decode — diagnostics only.
  List<JournalDecodeQuarantined> get lastLoadQuarantine =>
      List<JournalDecodeQuarantined>.unmodifiable(_lastLoadQuarantine);

  /// Currently signed-in account id, used to stamp newly created entries.
  /// Null while signed out (guest) — see [JournalOwnershipGuard].
  String? _activeOwnerKey;

  /// Updates which account newly-saved entries are stamped with. Does not
  /// retroactively change existing entries.
  void setActiveOwnerKey(String? ownerKey) {
    _activeOwnerKey = ownerKey;
  }

  void configureSaveInterceptorPipeline(
    JournalSaveInterceptorPipeline pipeline,
  ) {
    _saveInterceptorPipeline = pipeline;
  }

  static String encryptedPathFor(String legacyJsonPath) {
    if (legacyJsonPath.endsWith('.json')) {
      return legacyJsonPath.replaceFirst(RegExp(r'\.json$'), '.enc');
    }
    return '$legacyJsonPath.enc';
  }

  static Future<JournalStore> open(
    String filePath, {
    PrivateDataEncryptionKeyStore? keyStore,
    bool encryptAtRest = true,
    SecureStorageService? secureStorage,
    CognitiveAnalyzer? cognitiveAnalyzer,
    JournalSaveInterceptorPipeline? saveInterceptorPipeline,
    String? keyAlias,
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
        cognitiveAnalyzer: cognitiveAnalyzer,
        saveInterceptorPipeline: saveInterceptorPipeline,
      );
      store._cache = store._decodeEntries(await legacyFile.readAsString());
      return store;
    }

    final resolvedKeyStore =
        keyStore ?? _defaultKeyStore(secureStorage, keyAlias: keyAlias);
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
    );
    store._cache = await store._loadEntriesFromEncrypted();
    return store;
  }

  Future<void> clearAll() async {
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) return;
    _cache = const [];
    if (_encrypted != null) {
      await _encrypted.writeJson([]);
      return;
    }
    await file.writeAsString('[]');
  }

  Future<void> save(
    JournalEntry entry, {
    String first25Source = 'journal_save',
    String captureKind = 'typed',
  }) async {
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) return;
    // Must include tombstones here: this list is used to rebuild the
    // entire on-disk file below, and using the tombstone-filtered
    // `loadAll()` would silently erase every other pending tombstone on
    // every save.
    final all = await loadAllIncludingTombstones();
    final activeCountBefore = all.where((e) => !e.isDeleted).length;
    final isNew = !all.any((e) => e.id == entry.id);
    var toPersist = entry;
    if (isNew) {
      toPersist = await EntrySaveCoordinator.applyNewEntryOptions(
        toPersist,
        entryCount: activeCountBefore + 1,
      );
    }
    if (!toPersist.isDeleted) {
      toPersist = _cognitiveAnalyzer.enrichEntry(toPersist);
    }
    if (isNew && toPersist.ownerKey == null && _activeOwnerKey != null) {
      toPersist = toPersist.copyWith(ownerKey: _activeOwnerKey);
    }
    final next = [toPersist, ...all.where((e) => e.id != entry.id)];
    await _writeAll(next);
    if (isNew && !toPersist.isDeleted) {
      final activeCountAfter = activeCountBefore + 1;
      await BetaAnalyticsMilestoneCoordinator.onDurableSave(
        activeCountAfter: activeCountAfter,
        captureKind: captureKind,
        savedAt: toPersist.createdAt,
      );
      if (activeCountAfter == 1) {
        InviteFunnelMetrics.firstSave();
      }
    }
    await First25JournalHooks.onJournalSave(
      entry: entry,
      isNew: isNew,
      source: first25Source,
    );
    await _saveInterceptorPipeline.execute(toPersist);
  }

  Future<void> update(JournalEntry entry) async => save(entry);

  /// Persists a genuine content/metadata edit: bumps revision/updatedAt/
  /// changeId via [JournalEntry.markEdited] before saving, so the change
  /// is visible to sync. Prefer this over [save] for user-initiated edits;
  /// [save] itself does not version-bump, since it is also used for
  /// non-edit bookkeeping (sync acknowledgement, ownership stamping).
  Future<void> saveEdit(
    JournalEntry entry, {
    String first25Source = 'journal_save',
  }) async {
    await save(entry.markEdited(), first25Source: first25Source);
  }

  Future<void> updateCaptureContextTag(String id, {String? tagId}) async {
    final entry = await getById(id);
    if (entry == null) return;
    await saveEdit(CaptureContextTags.updateTag(entry, tagId));
  }

  /// All entries excluding tombstones (locally deleted entries pending
  /// server acknowledgement / retention). This is the query every normal
  /// UI/eligibility path should use.
  Future<List<JournalEntry>> loadAll() async {
    return (await loadAllIncludingTombstones())
        .where((e) => !e.isDeleted)
        .toList();
  }

  /// Same as [loadAll] but synchronous — uses the in-memory cache after [open].
  List<JournalEntry> loadAllSync() {
    return loadAllIncludingTombstonesSync().where((e) => !e.isDeleted).toList();
  }

  /// Every entry including tombstones. Used by sync (to propagate/pull
  /// deletions) and by [compactTombstones]. Normal UI code must not call
  /// this directly — use [loadAll].
  Future<List<JournalEntry>> loadAllIncludingTombstones() async {
    if (ArchiveMeDemoState.isActive) {
      return ArchiveMeDemoArchive.journalEntries();
    }
    if (CreatorDemoMode.isActive) {
      return CreatorDemoMode.demoJournalEntries();
    }
    if (_encryptAtRest && _encrypted != null) {
      _cache = await _loadEntriesFromEncrypted();
      return List<JournalEntry>.from(_cache!);
    }
    return loadAllIncludingTombstonesSync();
  }

  List<JournalEntry> loadAllIncludingTombstonesSync() {
    if (ArchiveMeDemoState.isActive) {
      return ArchiveMeDemoArchive.journalEntries();
    }
    if (CreatorDemoMode.isActive) return CreatorDemoMode.demoJournalEntries();
    if (_cache != null) {
      return List<JournalEntry>.from(_cache!);
    }

    final source = _encryptAtRest ? file : (_plaintextLegacy ?? file);
    if (!source.existsSync()) return [];
    final raw = source.readAsStringSync();
    if (raw.trim().isEmpty) return [];
    _cache = _decodeEntries(raw);
    return List<JournalEntry>.from(_cache!);
  }

  Future<List<JournalEntry>> loadEligible() async {
    final all = await loadAll();
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
    final all = await loadAll();
    return all
        .where(
          (e) =>
              e.syncStatus == SyncStatus.pendingUpload ||
              e.syncStatus == SyncStatus.localOnly,
        )
        .toList();
  }

  /// Tombstones not yet acknowledged by the server — these must be pushed
  /// on the next sync so other devices learn about the deletion.
  Future<List<JournalEntry>> pendingTombstones() async {
    final all = await loadAllIncludingTombstones();
    return all
        .where(
          (e) =>
              e.isDeleted &&
              (e.syncStatus == SyncStatus.pendingUpload ||
                  e.syncStatus == SyncStatus.localOnly),
        )
        .toList();
  }

  Future<void> markSynced(String id) async => markSyncedBatch({id});

  Future<void> markSyncedBatch(Set<String> ids) async {
    if (ids.isEmpty) return;
    await _mutateBatch((entries) {
      var changed = false;
      for (var i = 0; i < entries.length; i++) {
        if (!ids.contains(entries[i].id)) continue;
        entries[i] = entries[i].markSyncAcknowledged();
        changed = true;
      }
      return changed;
    });
  }

  /// Merges entries pulled from the server, including tombstones, using
  /// revision-based optimistic concurrency with field-level merge via
  /// [JournalConflictResolver].
  Future<void> mergeRemote(List<JournalEntry> remote) async =>
      mergeRemoteBatch(remote);

  Future<void> mergeRemoteBatch(List<JournalEntry> remote) async {
    if (remote.isEmpty) return;
    await _mutateBatch((entries) {
      final byId = {for (final e in entries) e.id: e};
      var changed = false;
      for (final r in remote) {
        final existing = byId[r.id];
        if (existing == null) {
          byId[r.id] = r.copyWith(syncStatus: SyncStatus.synced);
          changed = true;
          continue;
        }

        final result = JournalConflictResolver.resolve(
          local: existing,
          remote: r,
        );
        if (!result.shouldPersist) {
          continue;
        }

        byId[r.id] = result.entry.copyWith(
          localAudioPath: existing.localAudioPath,
          ownerKey: r.ownerKey ?? existing.ownerKey,
        );
        changed = true;
      }
      if (!changed) return false;
      entries
        ..clear()
        ..addAll(byId.values);
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return true;
    }, enrichNonTombstones: true);
  }

  Future<void> applyConflictWinnersBatch(
    Map<String, JournalEntry> winners,
  ) async {
    if (winners.isEmpty) return;
    await _mutateBatch((entries) {
      final byId = {for (final e in entries) e.id: e};
      var changed = false;
      for (final entry in winners.values) {
        final existing = byId[entry.id];
        if (existing == null) {
          byId[entry.id] = entry;
          changed = true;
          continue;
        }
        final result = JournalConflictResolver.resolve(
          local: existing,
          remote: entry,
        );
        if (result.shouldPersist) {
          byId[entry.id] = result.entry.copyWith(
            localAudioPath: existing.localAudioPath,
          );
          changed = true;
        }
      }
      if (!changed) return false;
      entries
        ..clear()
        ..addAll(byId.values);
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return true;
    }, enrichNonTombstones: true);
  }

  /// Soft local delete: creates a tombstone rather than forgetting the
  /// entry existed, so the deletion can propagate to other devices and
  /// never resurrects there. The entry disappears from [loadAll] / normal
  /// UI queries immediately. Use [compactTombstones] to physically purge
  /// tombstones once they are safe to forget. For a full account wipe
  /// (hard purge, no propagation), use [clearAll] instead.
  Future<void> delete(String id) async {
    final entry = await getByIdIncludingTombstones(id);
    if (entry == null || entry.isDeleted) return;
    await save(entry.markDeleted());
  }

  Future<JournalEntry?> getById(String id) async {
    final all = await loadAll();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<JournalEntry?> findByCaptureContextTag(String tag) async {
    final all = await loadAllIncludingTombstones();
    for (final entry in all) {
      if (entry.captureContextTag == tag) {
        return entry;
      }
    }
    return null;
  }

  /// Like [getById] but also returns tombstoned entries — needed by sync
  /// and by [markSynced]/[delete] themselves, which must operate on
  /// tombstones too.
  Future<JournalEntry?> getByIdIncludingTombstones(String id) async {
    final all = await loadAllIncludingTombstones();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Permanently removes tombstones that the server has acknowledged
  /// ([SyncStatus.synced]) and whose retention window has elapsed. This is
  /// the only place a tombstone is ever physically forgotten short of a
  /// full account wipe. Returns the number of tombstones purged.
  Future<int> compactTombstones({
    Duration retention = const Duration(days: 30),
    DateTime Function() now = DateTime.now,
  }) async => compactTombstonesBatch(retention: retention, now: now);

  Future<int> compactTombstonesBatch({
    Duration retention = const Duration(days: 30),
    DateTime Function()? now,
  }) async {
    final cutoff = (now ?? DateTime.now)().toUtc().subtract(retention);
    var purged = 0;
    await _mutateBatch((entries) {
      final kept = <JournalEntry>[];
      for (final e in entries) {
        final shouldPurge =
            e.isDeleted &&
            e.syncStatus == SyncStatus.synced &&
            e.deletedAt != null &&
            e.deletedAt!.isBefore(cutoff);
        if (shouldPurge) {
          purged++;
        } else {
          kept.add(e);
        }
      }
      if (purged == 0) return false;
      entries
        ..clear()
        ..addAll(kept);
      return true;
    });
    return purged;
  }

  Future<String> exportJson() async {
    final all = await loadAll();
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(all.map((e) => e.toJson()).toList());
  }

  /// Replaces the on-device journal — local backup restore only.
  Future<void> replaceAll(List<JournalEntry> entries) async {
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) return;
    final next = List<JournalEntry>.from(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _writeAll(next);
  }

  Future<void> _writeAll(List<JournalEntry> entries) async {
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) return;
    _cache = List<JournalEntry>.from(entries);
    JournalStoreWriteInstrumentation.persistCount++;
    final encoded = entries.map((e) => e.toJson()).toList();
    if (_encrypted != null) {
      await _encrypted.writeJson(encoded);
      return;
    }
    await file.writeAsString(jsonEncode(encoded));
  }

  Future<void> _mutateBatch(
    bool Function(List<JournalEntry> entries) mutate, {
    bool enrichNonTombstones = false,
  }) async {
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) return;
    final all = await loadAllIncludingTombstones();
    final working = List<JournalEntry>.from(all);
    final changed = mutate(working);
    if (!changed) return;
    if (enrichNonTombstones) {
      for (var i = 0; i < working.length; i++) {
        final e = working[i];
        if (!e.isDeleted) {
          working[i] = _cognitiveAnalyzer.enrichEntry(e);
        }
      }
    }
    await _writeAll(working);
  }

  Future<List<JournalEntry>> _loadEntriesFromEncrypted() async {
    if (_encrypted == null) return [];
    final decoded = await _encrypted.readJson();
    if (decoded == null) return [];
    return _decodeEntries(jsonEncode(decoded));
  }

  List<JournalEntry> _decodeEntries(String raw) {
    if (raw.trim().isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    _lastLoadQuarantine.clear();
    return JournalEntryDecoder.decodeList(
      list,
      quarantineOut: _lastLoadQuarantine,
    );
  }

  static PrivateDataEncryptionKeyStore _defaultKeyStore(
    SecureStorageService? secureStorage, {
    String? keyAlias,
  }) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return InMemoryPrivateDataEncryptionKeyStore();
    }
    return SecurePrivateDataEncryptionKeyStore(
      secure: secureStorage,
      keyAlias: keyAlias,
    );
  }
}

/// Test instrumentation — counts encrypted/plain journal persists.
class JournalStoreWriteInstrumentation {
  JournalStoreWriteInstrumentation._();
  static int persistCount = 0;
  static void reset() => persistCount = 0;
}