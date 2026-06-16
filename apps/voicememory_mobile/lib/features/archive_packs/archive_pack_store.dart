import '../../config/creator_demo_mode.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../memory/memory_scope.dart';
import '../memory/memory_scope_policy.dart';
import 'archive_pack.dart';
import 'archive_pack_scope_policy.dart';

/// Local store for Archive Packs — prefs-backed, no backend.
class ArchivePackStore {
  ArchivePackStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'archivePacks';

  static int _idCounter = 0;

  static ArchivePackStore instance() =>
      ArchivePackStore(AppServices.instance.prefs);

  static ArchivePackStore forPrefs(MobilePrefsStore prefs) =>
      ArchivePackStore(prefs);

  Future<List<ArchivePack>> loadAll() async {
    if (CreatorDemoMode.isActive) return const [];
    final raw = await _prefs.readMap(_key);
    if (raw == null) return [];
    final packs = raw.values
        .whereType<Map>()
        .map((m) => ArchivePack.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    packs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    ArchivePackScopePolicy.applyLoadedPacks(packs);
    return packs;
  }

  Future<ArchivePack?> getById(String id) async {
    final all = await loadAll();
    for (final pack in all) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  Future<ArchivePack?> create(String name, {DateTime? now}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (CreatorDemoMode.isActive) return null;
    final at = now ?? DateTime.now();
    final pack = ArchivePack(
      id: 'pack_${at.microsecondsSinceEpoch}_${_idCounter++}',
      name: trimmed,
      createdAt: at,
      updatedAt: at,
    );
    await _put(pack);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archivePackCreated,
      source: 'record',
      packCountBucket: ActivationFunnelAnalytics.resultCountBucket(
        (await loadAll()).length,
      ),
    );
    return pack;
  }

  Future<ArchivePack?> rename(String id, String name, {DateTime? now}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    return _update(
      id,
      (p) => p.copyWith(name: trimmed, updatedAt: now ?? DateTime.now()),
    );
  }

  /// Deletes the pack only — entries stay in the archive untouched.
  Future<void> delete(String id) async {
    if (CreatorDemoMode.isActive) return;
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      map.remove(id);
      return map;
    });
    await loadAll();
  }

  Future<ArchivePack?> assignEntry(
    String packId,
    String entryId, {
    DateTime? now,
  }) async {
    final result = await _update(packId, (p) {
      if (p.contains(entryId)) return p;
      return p.copyWith(
        entryIds: [...p.entryIds, entryId],
        updatedAt: now ?? DateTime.now(),
      );
    });
    if (result != null) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.entryAssignedToPack,
        source: 'save',
        memoryScope: MemoryScopePolicy.scope.id,
      );
    }
    return result;
  }

  Future<ArchivePack?> removeEntry(
    String packId,
    String entryId, {
    DateTime? now,
  }) async => _update(packId, (p) {
    if (!p.contains(entryId)) return p;
    return p.copyWith(
      entryIds: p.entryIds.where((id) => id != entryId).toList(),
      updatedAt: now ?? DateTime.now(),
    );
  });

  Future<ArchivePack?> saveInstructions(
    String id,
    String instructions, {
    DateTime? now,
  }) async {
    final result = await _update(
      id,
      (p) => p.copyWith(
        instructions: instructions.trim(),
        updatedAt: now ?? DateTime.now(),
      ),
    );
    if (result != null) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.archivePackInstructionsSaved,
        source: 'pack_detail',
      );
    }
    return result;
  }

  Future<ArchivePack?> setAllowCrossPackConnections(
    String id,
    bool allowed, {
    DateTime? now,
  }) async => _update(
    id,
    (p) => p.copyWith(
      allowCrossPackConnections: allowed,
      updatedAt: now ?? DateTime.now(),
    ),
  );

  Future<ArchivePack?> _update(
    String id,
    ArchivePack Function(ArchivePack) transform,
  ) async {
    if (CreatorDemoMode.isActive) return null;
    ArchivePack? result;
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      final raw = map[id];
      if (raw is! Map) return map;
      final updated = transform(
        ArchivePack.fromJson(Map<String, dynamic>.from(raw)),
      );
      result = updated;
      map[id] = updated.toJson();
      return map;
    });
    if (result != null) await loadAll();
    return result;
  }

  Future<void> _put(ArchivePack pack) async {
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      map[pack.id] = pack.toJson();
      return map;
    });
    await loadAll();
  }
}
