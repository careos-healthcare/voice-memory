import '../../config/creator_demo_mode.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'archive_action_item.dart';
import '../trust/archive_trust_receipt.dart';

/// Local store for user-confirmed action items — prefs-backed, no backend.
///
/// Action items are created only when the user taps Remember this and
/// confirms in the editor. Nothing here auto-extracts from summaries.
class ActionItemStore {
  ActionItemStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'archiveActionItems';

  static int _idCounter = 0;

  static ActionItemStore instance() =>
      ActionItemStore(AppServices.instance.prefs);

  static ActionItemStore forPrefs(MobilePrefsStore prefs) =>
      ActionItemStore(prefs);

  Future<List<ArchiveActionItem>> loadAll() async {
    if (CreatorDemoMode.isActive) return const [];
    final raw = await _prefs.readMap(_key);
    if (raw == null) return [];
    final items = raw.values
        .whereType<Map>()
        .map((m) => ArchiveActionItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<ArchiveActionItem?> getById(String id) async {
    final all = await loadAll();
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<List<ArchiveActionItem>> forEntry(String sourceEntryId) async {
    final all = await loadAll();
    return all.where((item) => item.sourceEntryId == sourceEntryId).toList();
  }

  Future<ArchiveActionItem?> openItemForEntry(String sourceEntryId) async {
    final items = await forEntry(sourceEntryId);
    for (final item in items) {
      if (item.isOpen) return item;
    }
    return null;
  }

  Future<ArchiveActionItem?> create({
    required String sourceEntryId,
    required String title,
    String note = '',
    DateTime? dueAt,
    bool? isReminderEnabled,
    String? archivePackId,
    String? archiveThreadId,
    List<String> collectionIds = const [],
    DateTime? now,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return null;
    if (CreatorDemoMode.isActive) return null;
    final at = now ?? DateTime.now();
    final item = ArchiveActionItem(
      id: 'action_${at.microsecondsSinceEpoch}_${_idCounter++}',
      sourceEntryId: sourceEntryId,
      title: trimmedTitle,
      note: note.trim(),
      createdAt: at,
      updatedAt: at,
      status: ActionItemStatus.open,
      dueAt: dueAt,
      isReminderEnabled: isReminderEnabled,
      archivePackId: archivePackId,
      archiveThreadId: archiveThreadId,
      collectionIds: collectionIds,
    );
    await _put(item);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.actionItemCreated,
      source: 'remember_this',
      status: ActionItemStatus.open,
      actionItemCountBucket: ActivationFunnelAnalytics.resultCountBucket(
        (await loadAll()).where((i) => !i.isDismissed).length,
      ),
    );
    if (AppServices.isInitialized) {
      try {
        final entries = await AppServices.instance.journalStore.loadAll();
        ArchiveTrustReceipt.noteActionItemCreated(
          entryCount: entries.where((e) => !e.isArchived).length,
        );
      } catch (_) {
        // Trust receipt is optional — action item save still succeeded.
      }
    }
    return item;
  }

  Future<ArchiveActionItem?> update({
    required String id,
    String? title,
    String? note,
    DateTime? Function()? dueAt,
    bool? isReminderEnabled,
    bool clearDueAt = false,
    DateTime? now,
  }) async {
    return _update(id, (item) {
      final trimmedTitle = title?.trim();
      if (trimmedTitle != null && trimmedTitle.isEmpty) return item;
      return item.copyWith(
        title: trimmedTitle,
        note: note?.trim(),
        updatedAt: now ?? DateTime.now(),
        dueAt: dueAt,
        isReminderEnabled: isReminderEnabled,
        clearDueAt: clearDueAt,
      );
    }, event: ActivationFunnelAnalytics.actionItemUpdated);
  }

  Future<ArchiveActionItem?> markDone(String id, {DateTime? now}) async {
    return _update(
      id,
      (item) => item.copyWith(
        status: ActionItemStatus.done,
        updatedAt: now ?? DateTime.now(),
      ),
      event: ActivationFunnelAnalytics.actionItemMarkedDone,
      status: ActionItemStatus.done,
    );
  }

  /// Dismisses the action item only — the source entry stays untouched.
  Future<ArchiveActionItem?> dismiss(String id, {DateTime? now}) async {
    return _update(
      id,
      (item) => item.copyWith(
        status: ActionItemStatus.dismissed,
        updatedAt: now ?? DateTime.now(),
      ),
      event: ActivationFunnelAnalytics.actionItemDismissed,
      status: ActionItemStatus.dismissed,
    );
  }

  Future<ArchiveActionItem?> _update(
    String id,
    ArchiveActionItem Function(ArchiveActionItem) transform, {
    required String event,
    String? status,
  }) async {
    if (CreatorDemoMode.isActive) return null;
    ArchiveActionItem? result;
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      final raw = map[id];
      if (raw is! Map) return map;
      final existing = ArchiveActionItem.fromJson(
        Map<String, dynamic>.from(raw),
      );
      final next = transform(existing);
      if (identical(next, existing)) return map;
      map[id] = next.toJson();
      result = next;
      return map;
    });
    if (result != null) {
      ActivationFunnelAnalytics.track(
        event,
        source: 'action_items',
        status: status ?? result!.status,
      );
    }
    return result;
  }

  Future<void> _put(ArchiveActionItem item) async {
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      map[item.id] = item.toJson();
      return map;
    });
  }
}
