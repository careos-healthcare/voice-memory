import 'dart:convert';
import 'dart:io';

import '../features/first25/first25_journal_hooks.dart';
import '../models/journal_entry.dart';
import '../models/sync_status.dart';

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
    final all = await loadAll();
    final isNew = !all.any((e) => e.id == entry.id);
    final next = [entry, ...all.where((e) => e.id != entry.id)];
    await _writeAll(next);
    await First25JournalHooks.onJournalSave(
      entry: entry,
      isNew: isNew,
      source: first25Source,
    );
  }

  Future<void> update(JournalEntry entry) async => save(entry);

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
    return const JsonEncoder.withIndent('  ').convert(
      all.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> _writeAll(List<JournalEntry> entries) async {
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await file.writeAsString(encoded);
  }
}
