import 'dart:convert';
import 'dart:io';

import '../config/creator_demo_mode.dart';
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

/// Durable JSON journal file on device.
class JournalStore {
  JournalStore({required this.file});

  final File file;

  static Future<JournalStore> open(String filePath) async {
    final file = File(filePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    if (!await file.exists()) {
      await file.writeAsString('[]');
    }
    return JournalStore(file: file);
  }

  Future<List<JournalEntry>> loadAll() async => loadAllSync();

  /// Same as [loadAll] but synchronous — for instant empty-archive UI on cold open.
  List<JournalEntry> loadAllSync() {
    // Creator demo mode: safe demo entries only — the real journal file
    // is never read.
    if (CreatorDemoMode.isActive) return CreatorDemoMode.demoJournalEntries();
    if (!file.existsSync()) return [];
    final raw = file.readAsStringSync();
    if (raw.trim().isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final entries = list
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> save(
    JournalEntry entry, {
    String first25Source = 'journal_save',
  }) async {
    // Creator demo mode: never write demo (or new) entries into the real
    // journal file, and never fire first-save funnel hooks.
    if (CreatorDemoMode.isActive) return;
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
    // Funnel: the very first successful save in this archive.
    if (isNew && next.length == 1) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.firstRecordingSaved,
        entryCount: 1,
        oncePerSession: true,
      );
      // Attribute the first save to the rescue card when its CTA started
      // this recording. Counts only — never recording content.
      if (FirstSaveRescue.startedFromRescueThisSession) {
        FirstSaveRescue.startedFromRescueThisSession = false;
        ActivationFunnelAnalytics.track(
          ActivationFunnelAnalytics.firstSaveRescueSaved,
          entryCount: 1,
          oncePerSession: true,
        );
      }
      // Attribute the first save to the starter sentence when its CTA
      // seeded this recording. Counts only — never recording content.
      if (FirstRecordingSample.startedFromSampleThisSession) {
        FirstRecordingSample.startedFromSampleThisSession = false;
        ActivationFunnelAnalytics.track(
          ActivationFunnelAnalytics.firstRecordingSampleSaved,
          entryCount: 1,
          oncePerSession: true,
        );
      }
      // Invited funnel mirror: the very first save of an invited user.
      // Silent without a first-touch invite attribution.
      InviteFunnelMetrics.firstSave();
      // Attribute the first save to the invited-user welcome when its CTA
      // started this recording. Stable source id and counts only.
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

  /// Copy with memory metadata only — id, text, and timestamps untouched.
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

  /// Completed reflections (non-empty transcript).
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

  /// Merge remote entries — newer updatedAt wins per id.
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
          // Local memory metadata survives a remote merge.
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

  Future<void> _writeAll(List<JournalEntry> entries) async {
    // Creator demo mode: the real journal file is never touched.
    if (CreatorDemoMode.isActive) return;
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await file.writeAsString(encoded);
  }
}
