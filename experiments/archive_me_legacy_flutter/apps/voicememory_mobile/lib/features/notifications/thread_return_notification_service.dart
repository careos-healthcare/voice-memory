import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import '../tomorrow_return/check_in_reminder_service.dart';
import '../tomorrow_return/watch_for_model.dart';
import '../tomorrow_return/watch_for_store.dart';

abstract final class ThreadReturnNotificationCopy {
  ThreadReturnNotificationCopy._();

  static const title = 'ArchiveMe';

  static String body(String fragment) =>
      "You saved a thread about '$fragment' a few days ago. "
      'Come back if it showed up again today.';
}

enum AdaptiveReminderLevel {
  level1(1, Duration(days: 3)),
  level2(2, Duration(days: 7)),
  level3(3, Duration(days: 14));

  const AdaptiveReminderLevel(this.number, this.interval);

  final int number;
  final Duration interval;
}

/// One-shot, adaptive reminders for active Watch Targets.
///
/// A target receives at most three reminders, spaced 3, then 7, then 14 days
/// apart. Fire times are shifted when needed so no two target reminders occur
/// within the same rolling 24-hour window.
abstract final class ThreadReturnNotificationService {
  ThreadReturnNotificationService._();

  static const prefsKey = 'threadReturnNotifications_v1';
  static const snoozeDuration = Duration(days: 7);
  static const globalCooldown = Duration(hours: 24);
  static const payloadPrefix = 'thread_return_v2:';

  static CheckInReminderBackend get _backend => CheckInReminderService.backend;
  static WatchForStore get _watchStore =>
      WatchForStore(AppServices.instance.prefs);

  /// Removes notifications created by the previous fixed-delay engine.
  static Future<void> initialize() async {
    if (!AppServices.isInitialized) return;
    final raw = await AppServices.instance.prefs.readMap(prefsKey);
    final pending = raw?['pending'];
    if (pending is! List) return;
    final legacy = pending.whereType<Map>().where(
      (item) => item['level'] == null || item['scheduledAt'] == null,
    );
    var foundLegacy = false;
    for (final item in legacy) {
      foundLegacy = true;
      final key = item['notificationKey'];
      if (key is String && key.isNotEmpty && _backend.isAvailable) {
        await _backend.cancel(key);
      }
    }
    if (foundLegacy) {
      await _writeState(const _AdaptiveNotificationState.empty());
    }
  }

  static Future<void> onMomentSaved(JournalEntry entry, {DateTime? now}) async {
    if (!AppServices.isInitialized || !_backend.isAvailable) return;
    final target = await _watchStore.readPending();
    if (target == null) return;

    // Saving while this target is active is new linked evidence. It resets a
    // previous "Don't remind again" choice before starting a fresh sequence.
    if (target.isSuppressed) {
      await _watchStore.updateActive(target.copyWith(isSuppressed: false));
    }
    await _scheduleForTarget(
      target: target.copyWith(isSuppressed: false),
      sourceEntryId: target.sourceReflectionId ?? entry.id,
      processedEntryId: entry.id,
      fallbackFragment: fragmentForEntry(entry),
      now: now,
      resetPermanentSuppression: true,
    );
  }

  /// Schedules the first sequence when a Watch Target is accepted after save.
  static Future<void> onWatchTargetActivated(
    WatchForItem target, {
    DateTime? now,
  }) async {
    if (!AppServices.isInitialized || !_backend.isAvailable) return;
    await _scheduleForTarget(
      target: target,
      sourceEntryId: target.sourceReflectionId ?? target.id,
      processedEntryId: target.sourceReflectionId ?? target.id,
      fallbackFragment: null,
      now: now,
    );
  }

  static Future<void> _scheduleForTarget({
    required WatchForItem target,
    required String sourceEntryId,
    required String processedEntryId,
    required String? fallbackFragment,
    DateTime? now,
    Duration? firstDelay,
    bool resetPermanentSuppression = false,
  }) async {
    if (target.isSuppressed) return;
    final fragment =
        _safeFragment(target.displayShortPrompt) ?? fallbackFragment;
    if (fragment == null) return;

    final clock = (now ?? DateTime.now()).toUtc();
    var state = (await _loadState()).pruned(clock);
    final targetKey = _targetKey(target.id);
    if (state.permanentlySuppressedTargetKeys.contains(targetKey) &&
        !resetPermanentSuppression) {
      return;
    }
    if (state.processedEntryIds.contains(processedEntryId) &&
        firstDelay == null) {
      return;
    }

    await _cancelPending(state.forTarget(targetKey));
    state = state.withoutTarget(targetKey);

    final granted = await _backend.requestPermission();
    if (!granted) return;

    final scheduled = <_PendingThreadNotification>[];
    var cursor = clock;
    for (final level in AdaptiveReminderLevel.values) {
      final interval =
          level == AdaptiveReminderLevel.level1 && firstDelay != null
          ? firstDelay
          : level.interval;
      cursor = _nextAvailableTime(cursor.add(interval), [
        ...state.pending,
        ...scheduled,
      ]);
      final notification = _PendingThreadNotification(
        targetId: target.id,
        targetKey: targetKey,
        sourceEntryId: sourceEntryId,
        fragment: fragment,
        notificationKey: _notificationKey(target.id, level),
        level: level,
        scheduledAt: cursor,
      );
      await _scheduleQuiet(notification);
      scheduled.add(notification);
    }

    await _writeState(
      state.copyWith(
        pending: [...state.pending, ...scheduled],
        permanentlySuppressedTargetKeys: {
          for (final key in state.permanentlySuppressedTargetKeys)
            if (!resetPermanentSuppression || key != targetKey) key,
        },
        processedEntryIds: {...state.processedEntryIds, processedEntryId},
      ),
    );
  }

  static DateTime _nextAvailableTime(
    DateTime candidate,
    List<_PendingThreadNotification> pending,
  ) {
    var result = candidate;
    while (true) {
      final conflicts = pending
          .where(
            (item) =>
                item.scheduledAt.difference(result).abs() < globalCooldown,
          )
          .toList();
      if (conflicts.isEmpty) return result;
      conflicts.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      result = conflicts.last.scheduledAt.add(globalCooldown);
    }
  }

  static Future<void> _scheduleQuiet(_PendingThreadNotification notification) {
    final backend = _backend;
    if (backend is QuietReminderBackend) {
      return (backend as QuietReminderBackend).scheduleQuiet(
        checkInId: notification.notificationKey,
        title: ThreadReturnNotificationCopy.title,
        body: ThreadReturnNotificationCopy.body(notification.fragment),
        when: notification.scheduledAt.toLocal(),
        payload:
            '$payloadPrefix${notification.targetId}:${notification.level.number}',
      );
    }
    return backend.schedule(
      checkInId: notification.notificationKey,
      title: ThreadReturnNotificationCopy.title,
      body: ThreadReturnNotificationCopy.body(notification.fragment),
      when: notification.scheduledAt.toLocal(),
      payload:
          '$payloadPrefix${notification.targetId}:${notification.level.number}',
    );
  }

  /// Viewing the relevant evidence/thread cancels only that target's sequence.
  static Future<void> markThreadViewed(String? sourceEntryId) async {
    await _cancelMatching(sourceEntryId: sourceEntryId);
  }

  /// "Not today" postpones the target sequence by seven days.
  static Future<void> snoozeThread(
    String? sourceEntryId, {
    DateTime? now,
  }) async {
    if (!AppServices.isInitialized || !_backend.isAvailable) return;
    final state = (await _loadState()).pruned((now ?? DateTime.now()).toUtc());
    final matching = state.matchingSource(sourceEntryId);
    final activeTarget = await _activeTargetForSource(sourceEntryId);
    if (matching.isEmpty && activeTarget == null) return;
    final targetId = matching.firstOrNull?.targetId ?? activeTarget!.id;
    final targetKey = _targetKey(targetId);
    final source =
        matching.firstOrNull?.sourceEntryId ??
        activeTarget?.sourceReflectionId ??
        targetId;
    final fragment =
        matching.firstOrNull?.fragment ??
        _safeFragment(activeTarget?.displayShortPrompt ?? '');
    await _cancelPending(matching);
    final next = state.withoutTarget(targetKey);
    await _writeState(next);

    final target =
        activeTarget ??
        await _watchStore.readActive().then(
          (items) => items.where((item) => item.id == targetId).firstOrNull,
        );
    if (target == null || target.isSuppressed) return;
    await _scheduleForTarget(
      target: target,
      sourceEntryId: source,
      processedEntryId: source,
      fallbackFragment: fragment,
      now: now,
      firstDelay: snoozeDuration,
    );
  }

  /// "Don't remind again" persists until [onMomentSaved] links new evidence.
  static Future<void> suppressThreadPermanently(String? sourceEntryId) async {
    if (!AppServices.isInitialized) return;
    final state = await _loadState();
    final matching = state.matchingSource(sourceEntryId);
    final activeTarget = await _activeTargetForSource(sourceEntryId);
    if (matching.isEmpty && activeTarget == null) return;
    final targetId = matching.firstOrNull?.targetId ?? activeTarget!.id;
    final targetKey = _targetKey(targetId);
    await _cancelPending(matching);
    await _writeState(
      state
          .withoutTarget(targetKey)
          .copyWith(
            permanentlySuppressedTargetKeys: {
              ...state.permanentlySuppressedTargetKeys,
              targetKey,
            },
          ),
    );
    final active = await _watchStore.readActive();
    for (final target in active.where((item) => item.id == targetId)) {
      await _watchStore.updateActive(target.copyWith(isSuppressed: true));
    }
  }

  static Future<void> cancelForTarget(String targetId) async {
    await _cancelMatching(targetId: targetId);
  }

  static Future<void> threadCompleted(String targetId) =>
      cancelForTarget(targetId);

  static Future<void> threadMerged(String targetId) =>
      cancelForTarget(targetId);

  static Future<void> threadDeleted(String targetId) =>
      cancelForTarget(targetId);

  static Future<void> _cancelMatching({
    String? sourceEntryId,
    String? targetId,
  }) async {
    if (!AppServices.isInitialized) return;
    final source = sourceEntryId?.trim() ?? '';
    final target = targetId?.trim() ?? '';
    if (source.isEmpty && target.isEmpty) return;
    final state = await _loadState();
    final matching = source.isNotEmpty
        ? state.matchingSource(source)
        : state.pending.where((item) => item.targetId == target).toList();
    if (matching.isEmpty) return;
    await _cancelPending(matching);
    await _writeState(state.withoutTarget(matching.first.targetKey));
  }

  static Future<WatchForItem?> _activeTargetForSource(
    String? sourceEntryId,
  ) async {
    final source = sourceEntryId?.trim() ?? '';
    if (source.isEmpty) return null;
    final active = await _watchStore.readActive();
    return active
        .where((item) => item.sourceReflectionId == source || item.id == source)
        .firstOrNull;
  }

  static Future<void> _cancelPending(
    Iterable<_PendingThreadNotification> pending,
  ) async {
    if (!_backend.isAvailable) return;
    for (final item in pending) {
      await _backend.cancel(item.notificationKey);
    }
  }

  static String? fragmentForEntry(JournalEntry entry) {
    return _safeFragment(ComparableEvidenceText.userText(entry));
  }

  static String? _safeFragment(String value) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;
    final safe = text.replaceAll("'", '’');
    if (safe.length <= 72) return safe;
    return '${safe.substring(0, 71).trim()}…';
  }

  static Duration delayForLevel(AdaptiveReminderLevel level) => level.interval;

  static String _targetKey(String targetId) => 'watch:$targetId';

  static String _notificationKey(
    String targetId,
    AdaptiveReminderLevel level,
  ) => 'thread_return:$targetId:${level.number}';

  static Future<_AdaptiveNotificationState> _loadState() async {
    final raw = await AppServices.instance.prefs.readMap(prefsKey);
    return _AdaptiveNotificationState.fromMap(raw);
  }

  static Future<void> _writeState(_AdaptiveNotificationState state) {
    return AppServices.instance.prefs.writeMap(prefsKey, state.toMap());
  }

  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    if (prefs == null) return;
    await prefs.writeMap(prefsKey, {});
  }
}

class _PendingThreadNotification {
  const _PendingThreadNotification({
    required this.targetId,
    required this.targetKey,
    required this.sourceEntryId,
    required this.fragment,
    required this.notificationKey,
    required this.level,
    required this.scheduledAt,
  });

  final String targetId;
  final String targetKey;
  final String sourceEntryId;
  final String fragment;
  final String notificationKey;
  final AdaptiveReminderLevel level;
  final DateTime scheduledAt;

  Map<String, Object> toMap() => {
    'targetId': targetId,
    'targetKey': targetKey,
    'sourceEntryId': sourceEntryId,
    'fragment': fragment,
    'notificationKey': notificationKey,
    'level': level.number,
    'scheduledAt': scheduledAt.toIso8601String(),
  };

  static _PendingThreadNotification? fromMap(Map<String, dynamic> raw) {
    final levelNumber = raw['level'];
    final scheduledAt = DateTime.tryParse(raw['scheduledAt']?.toString() ?? '');
    final level = AdaptiveReminderLevel.values
        .where((value) => value.number == levelNumber)
        .firstOrNull;
    if (level == null || scheduledAt == null) return null;
    final targetId = raw['targetId']?.toString() ?? '';
    final targetKey = raw['targetKey']?.toString() ?? '';
    final sourceEntryId = raw['sourceEntryId']?.toString() ?? '';
    final fragment = raw['fragment']?.toString() ?? '';
    final notificationKey = raw['notificationKey']?.toString() ?? '';
    if (targetId.isEmpty ||
        targetKey.isEmpty ||
        sourceEntryId.isEmpty ||
        fragment.isEmpty ||
        notificationKey.isEmpty) {
      return null;
    }
    return _PendingThreadNotification(
      targetId: targetId,
      targetKey: targetKey,
      sourceEntryId: sourceEntryId,
      fragment: fragment,
      notificationKey: notificationKey,
      level: level,
      scheduledAt: scheduledAt.toUtc(),
    );
  }
}

class _AdaptiveNotificationState {
  const _AdaptiveNotificationState({
    required this.pending,
    required this.permanentlySuppressedTargetKeys,
    required this.processedEntryIds,
  });

  const _AdaptiveNotificationState.empty()
    : pending = const [],
      permanentlySuppressedTargetKeys = const {},
      processedEntryIds = const {};

  final List<_PendingThreadNotification> pending;
  final Set<String> permanentlySuppressedTargetKeys;
  final Set<String> processedEntryIds;

  factory _AdaptiveNotificationState.fromMap(Map<String, dynamic>? raw) {
    final pending = <_PendingThreadNotification>[];
    final pendingRaw = raw?['pending'];
    if (pendingRaw is List) {
      for (final item in pendingRaw.whereType<Map>()) {
        final parsed = _PendingThreadNotification.fromMap(
          Map<String, dynamic>.from(item),
        );
        if (parsed != null) pending.add(parsed);
      }
    }
    return _AdaptiveNotificationState(
      pending: pending,
      permanentlySuppressedTargetKeys:
          (raw?['permanentlySuppressedTargetKeys'] as List?)
              ?.whereType<String>()
              .toSet() ??
          const {},
      processedEntryIds:
          (raw?['processedEntryIds'] as List?)?.whereType<String>().toSet() ??
          const {},
    );
  }

  List<_PendingThreadNotification> forTarget(String targetKey) =>
      pending.where((item) => item.targetKey == targetKey).toList();

  List<_PendingThreadNotification> matchingSource(String? sourceEntryId) {
    final source = sourceEntryId?.trim() ?? '';
    if (source.isEmpty) return const [];
    return pending.where((item) => item.sourceEntryId == source).toList();
  }

  _AdaptiveNotificationState withoutTarget(String targetKey) => copyWith(
    pending: pending.where((item) => item.targetKey != targetKey).toList(),
  );

  _AdaptiveNotificationState pruned(DateTime now) => copyWith(
    pending: pending
        .where(
          (item) => item.scheduledAt.isAfter(
            now.subtract(ThreadReturnNotificationService.globalCooldown),
          ),
        )
        .toList(),
  );

  _AdaptiveNotificationState copyWith({
    List<_PendingThreadNotification>? pending,
    Set<String>? permanentlySuppressedTargetKeys,
    Set<String>? processedEntryIds,
  }) => _AdaptiveNotificationState(
    pending: pending ?? this.pending,
    permanentlySuppressedTargetKeys:
        permanentlySuppressedTargetKeys ?? this.permanentlySuppressedTargetKeys,
    processedEntryIds: processedEntryIds ?? this.processedEntryIds,
  );

  Map<String, Object> toMap() => {
    'schemaVersion': 2,
    'pending': pending.map((item) => item.toMap()).toList(),
    'permanentlySuppressedTargetKeys': permanentlySuppressedTargetKeys.toList(),
    'processedEntryIds': processedEntryIds.toList(),
  };
}
