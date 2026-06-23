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
      current.copyWith(
        records: nextRecords,
        lastVariantId: variantId,
      ),
    );
  }

  static Future<void> resetForTest() async {
    _cached = BetaInviteCopyStats.empty;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, {});
  }
}
