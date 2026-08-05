import 'dart:convert';
import 'dart:io';

import '../config/archive_me_demo_state.dart';
import '../features/demo/archive_me_demo_archive.dart';
import '../config/creator_demo_mode.dart';
import '../features/activation/capture_context_tags.dart';
import '../features/curiosity_loop/domain/services/cognitive_analyzer.dart';
import '../features/journal/infrastructure/journal_save_interceptor_pipeline.dart';
import '../features/first25/first25_journal_hooks.dart';
import '../features/memory/entry_save_coordinator.dart';
import '../features/first_session/first_recording_sample.dart';
import '../features/first_session/first_save_rescue.dart';
import '../features/referral/invite_funnel_metrics.dart';
import '../features/referral/invited_user_welcome.dart';
import '../models/journal_entry.dart';
import '../models/sync_status.dart';
import '../services/activation_funnel_analytics.dart';
import 'encrypted_json_file_store.dart';
import 'private_data_encryption_key_store.dart';
import 'secure_storage.dart';

/// Durable journal file on device — encrypted at rest when [encryptAtRest] is enabled.
class JournalStore {
  JournalStore({
    required this.file,
    EncryptedJsonFileStore? encryptedStore,
    File? plaintextLegacyFile,
    bool encryptAtRest = false,
    CognitiveAnalyzer? cognitiveAnalyzer,
    JournalSaveInterceptorPipeline? saveInterceptorPipeline,
  }) : _encrypted = encryptedStore,
       _plaintextLegacy = plaintextLegacyFile,
       _encryptAtRest = encryptAtRest,
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
        encryptAtRest: false,
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
      await _encrypted!.writeJson([]);
      return;
    }
    await file.writeAsString('[]');
  }

  Future<void> save(
    JournalEntry entry, {
    String first25Source = 'journal_save',
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
        entry,
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
    if (isNew && activeCountBefore + 1 == 1 && !toPersist.isDeleted) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.firstRecordingSaved,
        entryCount: 1,
        oncePerSession: true,
      );
      if (FirstSaveRescue.startedFromRescueThisSession) {
        FirstSaveRescue.startedFromRescueThisSession = false;
        ActivationFunnelAnalytics.track(
          ActivationFunnelAnalytics.firstSaveRescueSaved,
          entryCount: 1,
          oncePerSession: true,
        );
      }
      if (FirstRecordingSample.startedFromSampleThisSession) {
        FirstRecordingSample.startedFromSampleThisSession = false;
        ActivationFunnelAnalytics.track(
          ActivationFunnelAnalytics.firstRecordingSampleSaved,
          entryCount: 1,
          oncePerSession: true,
        );
      }
      InviteFunnelMetrics.firstSave();
      if (InvitedUserWelcome.startedFromWelcomeThisSession) {
        InvitedUserWelcome.startedFromWelcomeThisSession = false;
        ActivationFunnelAnalytics.track(
          ActivationFunnelAnalytics.invitedUserFirstSave,
          source: InvitedUserWelcome.sessionSource,
          entryCount: 1,
          oncePerSession: true,
        );
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

  Future<void> markSynced(String id) async {
    final entry = await getByIdIncludingTombstones(id);
    if (entry == null) return;
    await save(entry.markSyncAcknowledged());
  }

  /// Merges entries pulled from the server, including tombstones, using
  /// the shared [JournalSyncCompare] conflict comparator so mobile and
  /// server agree on which revision wins. A remote tombstone always
  /// overwrites a lower-priority local copy — it never resurrects a
  /// separately-deleted local entry, and a winning remote non-tombstone
  /// never un-deletes a higher-priority local tombstone.
  Future<void> mergeRemote(List<JournalEntry> remote) async {
    final local = await loadAllIncludingTombstones();
    final byId = {for (final e in local) e.id: e};
    for (final r in remote) {
      final existing = byId[r.id];
      if (existing == null || JournalSyncCompare.compare(r, existing) > 0) {
        // The remote copy wins outright, but device-local-only bookkeeping
        // (the local audio file path, and the owning-account stamp used by
        // JournalOwnershipGuard) is never something the server's revision
        // comparison should override, so both are preserved from the
        // existing local copy when present.
        byId[r.id] = r.copyWith(
          localAudioPath: existing?.localAudioPath,
          ownerKey: r.ownerKey ?? existing?.ownerKey,
          syncStatus: SyncStatus.synced,
        );
      }
    }
    final merged =
        byId.values
            .map((e) => e.isDeleted ? e : _cognitiveAnalyzer.enrichEntry(e))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _writeAll(merged);
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
  }) async {
    final all = await loadAllIncludingTombstones();
    final cutoff = now().toUtc().subtract(retention);
    final kept = <JournalEntry>[];
    var purged = 0;
    for (final e in all) {
      final shouldPurge =
          e.isDeleted &&
          e.syncStatus == SyncStatus.synced &&
          e.deletedAt!.isBefore(cutoff);
      if (shouldPurge) {
        purged++;
      } else {
        kept.add(e);
      }
    }
    if (purged > 0) {
      await _writeAll(kept);
    }
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
    final encoded = entries.map((e) => e.toJson()).toList();
    if (_encrypted != null) {
      await _encrypted!.writeJson(encoded);
      return;
    }
    await file.writeAsString(jsonEncode(encoded));
  }

  Future<List<JournalEntry>> _loadEntriesFromEncrypted() async {
    if (_encrypted == null) return [];
    final decoded = await _encrypted!.readJson();
    if (decoded == null) return [];
    return _decodeEntries(jsonEncode(decoded));
  }

  List<JournalEntry> _decodeEntries(String raw) {
    if (raw.trim().isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final entries = list
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
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
