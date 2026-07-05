import 'dart:convert';
import 'dart:io';

import '../config/archive_me_demo_state.dart';
import '../features/demo/archive_me_demo_archive.dart';
import '../config/creator_demo_mode.dart';
import '../features/activation/capture_context_tags.dart';
import '../features/first25/first25_journal_hooks.dart';
import '../features/memory/entry_memory_mode.dart';
import '../features/memory/entry_save_coordinator.dart';
import '../features/memory/entry_thread_scope.dart';
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
  }) : _encrypted = encryptedStore,
       _plaintextLegacy = plaintextLegacyFile,
       _encryptAtRest = encryptAtRest;

  /// Primary on-disk file — encrypted envelope when [encryptAtRest] is true.
  final File file;

  final EncryptedJsonFileStore? _encrypted;
  final File? _plaintextLegacy;
  final bool _encryptAtRest;

  List<JournalEntry>? _cache;

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
  }) async {
    final legacyFile = File(filePath);
    if (!await legacyFile.parent.exists()) {
      await legacyFile.parent.create(recursive: true);
    }

    if (!encryptAtRest) {
      if (!await legacyFile.exists()) {
        await legacyFile.writeAsString('[]');
      }
      final store = JournalStore(file: legacyFile, encryptAtRest: false);
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
    );
    store._cache = await store._loadEntriesFromEncrypted();
    return store;
  }

  Future<List<JournalEntry>> loadAll() async {
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
    return loadAllSync();
  }

  /// Same as [loadAll] but synchronous — uses the in-memory cache after [open].
  List<JournalEntry> loadAllSync() {
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
    final all = await loadAll();
    final isNew = !all.any((e) => e.id == entry.id);
    var toPersist = entry;
    if (isNew) {
      toPersist = await EntrySaveCoordinator.applyNewEntryOptions(
        entry,
        entryCount: all.length + 1,
      );
    }
    final next = [toPersist, ...all.where((e) => e.id != entry.id)];
    await _writeAll(next);
    if (isNew && next.length == 1) {
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
  }

  Future<void> update(JournalEntry entry) async => save(entry);

  Future<void> updateCaptureContextTag(String id, {String? tagId}) async {
    final entry = await getById(id);
    if (entry == null) return;
    await save(CaptureContextTags.updateTag(entry, tagId));
  }

  static JournalEntry _withMemoryFlags(
    JournalEntry entry, {
    bool? treatAsNew,
    bool? connectionApproved,
    bool? keepSeparate,
    String? archiveThreadId,
    String? archivePackId,
    String? captureContextTag,
  }) => JournalEntry(
    id: entry.id,
    createdAt: entry.createdAt,
    transcript: entry.transcript,
    durationSeconds: entry.durationSeconds,
    reflection: entry.reflection,
    syncStatus: entry.syncStatus,
    localAudioPath: entry.localAudioPath,
    treatAsNew: treatAsNew ?? entry.treatAsNew,
    connectionApproved: connectionApproved ?? entry.connectionApproved,
    keepExactDetails: entry.keepExactDetails,
    keepSeparate: keepSeparate ?? entry.keepSeparate,
    archiveThreadId: archiveThreadId ?? entry.archiveThreadId,
    archivePackId: archivePackId ?? entry.archivePackId,
    isPinned: entry.isPinned,
    pinnedAt: entry.pinnedAt,
    isArchived: entry.isArchived,
    archivedAt: entry.archivedAt,
    entryAboutness: entry.entryAboutness,
    memorySurfacing: entry.memorySurfacing,
    preserveOriginal: entry.preserveOriginal,
    captureContextTag: captureContextTag ?? entry.captureContextTag,
  );

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

  Future<void> markSynced(String id) async {
    final entry = await getById(id);
    if (entry == null) return;
    await save(
      JournalEntry(
        id: entry.id,
        createdAt: entry.createdAt,
        transcript: entry.transcript,
        durationSeconds: entry.durationSeconds,
        reflection: entry.reflection,
        syncStatus: SyncStatus.synced,
        localAudioPath: entry.localAudioPath,
        treatAsNew: entry.treatAsNew,
        connectionApproved: entry.connectionApproved,
        keepExactDetails: entry.keepExactDetails,
        keepSeparate: entry.keepSeparate,
        archiveThreadId: entry.archiveThreadId,
        archivePackId: entry.archivePackId,
        isPinned: entry.isPinned,
        pinnedAt: entry.pinnedAt,
        isArchived: entry.isArchived,
        archivedAt: entry.archivedAt,
        entryAboutness: entry.entryAboutness,
        memorySurfacing: entry.memorySurfacing,
        preserveOriginal: entry.preserveOriginal,
        captureContextTag: entry.captureContextTag,
      ),
    );
  }

  Future<void> mergeRemote(List<JournalEntry> remote) async {
    final local = await loadAll();
    final byId = {for (final e in local) e.id: e};
    for (final r in remote) {
      final existing = byId[r.id];
      if (existing == null || r.createdAt.isAfter(existing.createdAt)) {
        byId[r.id] = JournalEntry(
          id: r.id,
          createdAt: r.createdAt,
          transcript: r.transcript,
          durationSeconds: r.durationSeconds,
          reflection: r.reflection,
          syncStatus: SyncStatus.synced,
          localAudioPath: existing?.localAudioPath,
          treatAsNew: r.treatAsNew || (existing?.treatAsNew ?? false),
          connectionApproved:
              r.connectionApproved || (existing?.connectionApproved ?? false),
          keepExactDetails:
              r.keepExactDetails || (existing?.keepExactDetails ?? false),
          keepSeparate: r.keepSeparate || (existing?.keepSeparate ?? false),
          archiveThreadId: r.archiveThreadId ?? existing?.archiveThreadId,
          archivePackId: r.archivePackId ?? existing?.archivePackId,
          isPinned: r.isPinned || (existing?.isPinned ?? false),
          pinnedAt: r.pinnedAt ?? existing?.pinnedAt,
          isArchived: r.isArchived || (existing?.isArchived ?? false),
          archivedAt: r.archivedAt ?? existing?.archivedAt,
          entryAboutness: r.entryAboutness,
          memorySurfacing: r.memorySurfacing,
          preserveOriginal:
              r.preserveOriginal || (existing?.preserveOriginal ?? false),
          captureContextTag: r.captureContextTag ?? existing?.captureContextTag,
        );
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _writeAll(merged);
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    await _writeAll(all.where((e) => e.id != id).toList());
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
    SecureStorageService? secureStorage,
  ) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return InMemoryPrivateDataEncryptionKeyStore();
    }
    return SecurePrivateDataEncryptionKeyStore(secure: secureStorage);
  }
}
