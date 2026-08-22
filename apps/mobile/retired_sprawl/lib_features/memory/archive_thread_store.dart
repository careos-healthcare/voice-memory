import 'package:archiveme_mobile/config/creator_demo_mode.dart';
import 'package:archiveme_mobile/features/memory/archive_thread.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local store for user-created archive threads.
class ArchiveThreadStore {
  ArchiveThreadStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'archiveThreads';

  static int _idCounter = 0;

  static ArchiveThreadStore instance() =>
      ArchiveThreadStore(AppServices.instance.prefs);

  static ArchiveThreadStore forPrefs(MobilePrefsStore prefs) =>
      ArchiveThreadStore(prefs);

  Future<List<ArchiveThread>> loadAll() async {
    if (CreatorDemoMode.isActive) return const [];
    final raw = await _prefs.readMap(_key);
    if (raw == null) return [];
    final threads = raw.values
        .whereType<Map>()
        .map((m) => ArchiveThread.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return threads;
  }

  Future<ArchiveThread?> getById(String id) async {
    final all = await loadAll();
    for (final thread in all) {
      if (thread.id == id) return thread;
    }
    return null;
  }

  /// Creates a thread. Returns null when the trimmed name is empty.
  Future<ArchiveThread?> create(String name, {DateTime? now}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (CreatorDemoMode.isActive) return null;
    final at = now ?? DateTime.now();
    final thread = ArchiveThread(
      id: 'thr_${at.microsecondsSinceEpoch}_${_idCounter++}',
      name: trimmed,
      createdAt: at,
      updatedAt: at,
    );
    await _put(thread);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveThreadCreated,
      source: 'record',
    );
    return thread;
  }

  Future<ArchiveThread?> rename(String id, String name, {DateTime? now}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    return _update(
      id,
      (t) => t.copyWith(name: trimmed, updatedAt: now ?? DateTime.now()),
    );
  }

  Future<void> assignEntry(String threadId, String entryId) async {
    if (CreatorDemoMode.isActive) return;
    await _update(threadId, (t) {
      if (t.entryIds.contains(entryId)) return t;
      return t.copyWith(
        entryIds: [...t.entryIds, entryId],
        updatedAt: DateTime.now(),
      );
    });
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.entryAssignedToThread,
      source: 'record',
    );
  }

  Future<void> removeEntry(String threadId, String entryId) async {
    if (CreatorDemoMode.isActive) return;
    await _update(
      threadId,
      (t) => t.copyWith(
        entryIds: t.entryIds.where((id) => id != entryId).toList(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<ArchiveThread?> _update(
    String id,
    ArchiveThread Function(ArchiveThread) transform,
  ) async {
    if (CreatorDemoMode.isActive) return null;
    ArchiveThread? updated;
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      final raw = map[id];
      if (raw is! Map) return map;
      final thread = ArchiveThread.fromJson(Map<String, dynamic>.from(raw));
      updated = transform(thread);
      map[id] = updated!.toJson();
      return map;
    });
    return updated;
  }

  Future<void> _put(ArchiveThread thread) async {
    if (CreatorDemoMode.isActive) return;
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      map[thread.id] = thread.toJson();
      return map;
    });
  }
}