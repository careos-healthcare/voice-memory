import 'package:archiveme_mobile/config/creator_demo_mode.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_store.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local store for user-created saved details — prefs-backed, no backend.
///
/// Facts are created only when the user taps Save detail and confirms in
/// the editor. Nothing here auto-extracts from summaries or entry text.
class FactLedgerStore {
  FactLedgerStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'archiveFacts';

  static int _idCounter = 0;

  static FactLedgerStore instance() =>
      FactLedgerStore(AppServices.instance.prefs);

  static FactLedgerStore forPrefs(MobilePrefsStore prefs) =>
      FactLedgerStore(prefs);

  Future<List<ArchiveFact>> loadAll() async {
    if (CreatorDemoMode.isActive) return const [];
    final raw = await _prefs.readMap(_key);
    if (raw == null) return [];
    final facts = raw.values
        .whereType<Map>()
        .map((m) => ArchiveFact.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    facts.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return facts;
  }

  Future<ArchiveFact?> getById(String id) async {
    final all = await loadAll();
    for (final fact in all) {
      if (fact.id == id) return fact;
    }
    return null;
  }

  Future<List<ArchiveFact>> forEntry(String sourceEntryId) async {
    final all = await loadAll();
    return all.where((f) => f.sourceEntryId == sourceEntryId).toList();
  }

  Future<bool> entryHasFact(String sourceEntryId) async {
    final items = await forEntry(sourceEntryId);
    return items.isNotEmpty;
  }

  /// System-indexed exact word citation — not a user-initiated saved detail.
  Future<ArchiveFact?> upsertSystemCitation({
    required String id,
    required String sourceEntryId,
    required String quote,
    required String provenance,
    DateTime? now,
  }) async {
    final trimmed = quote.trim();
    if (trimmed.isEmpty || sourceEntryId.isEmpty) return null;
    if (CreatorDemoMode.isActive) return null;
    final at = now ?? DateTime.now();
    final fact = ArchiveFact(
      id: id,
      sourceEntryId: sourceEntryId,
      label: FactLedgerCopy.citationLabel,
      value: trimmed,
      note: provenance.trim(),
      createdAt: at,
      updatedAt: at,
      factType: FactType.evidenceCitation.id,
      preserveOriginal: true,
    );
    await _put(fact);
    return fact;
  }

  Future<ArchiveFact?> create({
    required String sourceEntryId,
    required String label,
    required String value,
    required String factType, String note = '',
    String? archivePackId,
    String? archiveThreadId,
    List<String> collectionIds = const [],
    DateTime? now,
    String source = 'save_detail',
  }) async {
    final trimmedLabel = label.trim();
    final trimmedValue = value.trim();
    if (trimmedLabel.isEmpty || trimmedValue.isEmpty) return null;
    if (CreatorDemoMode.isActive) return null;
    final at = now ?? DateTime.now();
    final fact = ArchiveFact(
      id: 'fact_${at.microsecondsSinceEpoch}_${_idCounter++}',
      sourceEntryId: sourceEntryId,
      label: trimmedLabel,
      value: trimmedValue,
      note: note.trim(),
      createdAt: at,
      updatedAt: at,
      factType: FactType.fromId(factType).id,
      archivePackId: archivePackId,
      archiveThreadId: archiveThreadId,
      collectionIds: collectionIds,
    );
    await _put(fact);
    await _applyPreservationToSource(sourceEntryId);
    final count = (await loadAll()).length;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.factCreated,
      source: source,
      factType: fact.factType,
      factCountBucket: ActivationFunnelAnalytics.resultCountBucket(count),
      memoryScope: MemoryScopePolicy.scope.id,
    );
    return fact;
  }

  Future<ArchiveFact?> update({
    required String id,
    String? label,
    String? value,
    String? note,
    String? factType,
    DateTime? now,
    String source = 'details',
  }) async {
    return _update(
      id,
      (fact) {
        final trimmedLabel = label?.trim();
        final trimmedValue = value?.trim();
        if (trimmedLabel != null && trimmedLabel.isEmpty) return fact;
        if (trimmedValue != null && trimmedValue.isEmpty) return fact;
        return fact.copyWith(
          label: trimmedLabel,
          value: trimmedValue,
          note: note?.trim(),
          factType: factType != null ? FactType.fromId(factType).id : null,
          updatedAt: now ?? DateTime.now(),
        );
      },
      event: ActivationFunnelAnalytics.factUpdated,
      source: source,
    );
  }

  Future<ArchiveFact?> togglePin(String id, {DateTime? now}) async {
    return _update(
      id,
      (fact) => fact.copyWith(
        isPinned: !fact.isPinned,
        updatedAt: now ?? DateTime.now(),
      ),
      event: ActivationFunnelAnalytics.factPinned,
      source: 'details',
    );
  }

  /// Deletes the fact only — the source entry stays untouched.
  Future<bool> delete(String id) async {
    if (CreatorDemoMode.isActive) return false;
    var removed = false;
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      removed = map.remove(id) != null;
      return map;
    });
    if (removed) {
      final count = (await loadAll()).length;
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.factDeleted,
        source: 'details',
        factCountBucket: ActivationFunnelAnalytics.resultCountBucket(count),
        memoryScope: MemoryScopePolicy.scope.id,
      );
    }
    return removed;
  }

  Future<ArchiveFact?> _update(
    String id,
    ArchiveFact Function(ArchiveFact) transform, {
    required String event,
    required String source,
  }) async {
    if (CreatorDemoMode.isActive) return null;
    ArchiveFact? result;
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      final raw = map[id];
      if (raw is! Map) return map;
      final existing = ArchiveFact.fromJson(Map<String, dynamic>.from(raw));
      final next = transform(existing);
      if (identical(next, existing)) return map;
      map[id] = next.toJson();
      result = next;
      return map;
    });
    if (result != null) {
      ActivationFunnelAnalytics.track(
        event,
        source: source,
        factType: result!.factType,
        factCountBucket: ActivationFunnelAnalytics.resultCountBucket(
          (await loadAll()).length,
        ),
        memoryScope: MemoryScopePolicy.scope.id,
      );
    }
    return result;
  }

  Future<void> _put(ArchiveFact fact) async {
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      map[fact.id] = fact.toJson();
      return map;
    });
  }

  Future<void> _applyPreservationToSource(String sourceEntryId) async {
    if (!AppServices.isInitialized) return;
    try {
      final entry = await AppServices.instance.journalStore.getById(
        sourceEntryId,
      );
      if (entry == null || entry.preserveOriginal) return;
      final updated = entry.copyWith(preserveOriginal: true);
      await AppServices.instance.journalStore.update(updated);
      await PressureCheckInStore.instance().syncFromJournalEntry(updated);
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Preservation is optional — fact save still succeeded.
    }
  }
}