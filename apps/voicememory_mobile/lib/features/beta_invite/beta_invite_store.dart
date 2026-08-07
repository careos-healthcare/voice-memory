import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'beta_invite_models.dart';

/// Local-only beta invite copy counts — never uploads invite text.
class BetaInviteStore {
  BetaInviteStore(this._prefs);

  static const prefsKey = 'archiveBetaInviteCopies';

  final MobilePrefsStore _prefs;

  static BetaInviteCopyStats _cached = BetaInviteCopyStats.empty;
  static bool _loaded = false;

  static BetaInviteCopyStats get cached => _cached;

  static BetaInviteStore instance() =>
      BetaInviteStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().load();
    _loaded = true;
  }

  Future<BetaInviteCopyStats> load() async {
    final raw = await _prefs.readMap(prefsKey);
    return BetaInviteCopyStats.fromJson(raw);
  }

  Future<void> save(BetaInviteCopyStats stats) async {
    await _prefs.writeMap(prefsKey, stats.toJson());
    _cached = stats;
    _loaded = true;
  }

  Future<void> recordShortCopy(BetaInviteVariantId variantId) async {
    await _record(
      variantId,
      (stats) => stats.copyWith(shortCopiedCount: stats.shortCopiedCount + 1),
    );
  }

  Future<void> recordFullCopy(BetaInviteVariantId variantId) async {
    await _record(
      variantId,
      (stats) => stats.copyWith(fullCopiedCount: stats.fullCopiedCount + 1),
    );
  }

  Future<void> recordTaskCopy(BetaInviteVariantId variantId) async {
    await _record(
      variantId,
      (stats) => stats.copyWith(taskCopiedCount: stats.taskCopiedCount + 1),
    );
  }

  Future<void> _record(
    BetaInviteVariantId variantId,
    BetaInviteVariantStats Function(BetaInviteVariantStats current) mutate,
  ) async {
    final current = await load();
    final existing = current.statsFor(variantId);
    final nextRecords = Map<BetaInviteVariantId, BetaInviteVariantStats>.from(
      current.records,
    );
    nextRecords[variantId] = mutate(
      existing.copyWith(lastCopiedAt: DateTime.now().toUtc()),
    );
    await save(
      current.copyWith(records: nextRecords, lastVariantId: variantId),
    );
  }

  static Future<void> resetForTest() async {
    _cached = BetaInviteCopyStats.empty;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, {});
  }
}

/// Session + daily dismiss for the beta invite loop card.
abstract final class BetaInviteLoopDismissStore {
  BetaInviteLoopDismissStore._();

  static const prefsKey = 'betaInviteLoopDismissedDateKey_v1';

  static bool _sessionDismissed = false;
  static String? _loadedDateKey;
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _loadedDateKey = await AppServices.instance.prefs.readString(prefsKey);
    _loaded = true;
  }

  static bool isDismissed({DateTime? now}) {
    if (_sessionDismissed) return true;
    final stored = _loadedDateKey;
    if (stored == null || stored.isEmpty) return false;
    final today = _dateKey(now ?? DateTime.now());
    return stored == today;
  }

  static Future<void> dismiss({DateTime? now}) async {
    _sessionDismissed = true;
    final day = _dateKey(now ?? DateTime.now());
    _loadedDateKey = day;
    _loaded = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeString(prefsKey, day);
  }

  static String _dateKey(DateTime when) {
    final utc = when.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  @visibleForTesting
  static void invalidateSessionForTest() {
    _sessionDismissed = false;
    _loadedDateKey = null;
    _loaded = false;
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    invalidateSessionForTest();
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeString(prefsKey, '');
  }
}
