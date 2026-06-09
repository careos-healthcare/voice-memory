import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';

/// Local stop-cost reflection answers keyed by journal entry id.
class ProveEnoughStopCostStore {
  ProveEnoughStopCostStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'proveEnoughStopCostReflections';

  static ProveEnoughStopCostStore instance() =>
      ProveEnoughStopCostStore(AppServices.instance.prefs);

  static ProveEnoughStopCostStore forPrefs(MobilePrefsStore prefs) =>
      ProveEnoughStopCostStore(prefs);

  Future<String?> load(String entryId) async {
    final raw = await _prefs.readMap(_key);
    if (raw == null) return null;
    final value = raw[entryId];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  Future<void> save({
    required String entryId,
    required String answer,
  }) async {
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      map[entryId] = answer.trim();
      return map;
    });
  }
}
