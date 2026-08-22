import 'package:archiveme_mobile/features/daily_discoveries/daily_discovery_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists viewed discovery ids, baseline snapshot, and pending today card.
class DailyDiscoveryStore {
  DailyDiscoveryStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _viewedKey = 'dailyDiscoveryViewedIds';
  static const _baselineKey = 'dailyDiscoveryBaseline';
  static const _pendingKey = 'dailyDiscoveryPending';

  Future<Set<String>> readViewedIds() async {
    final raw = await _prefs.readJsonMap(_viewedKey);
    final list = raw?['ids'];
    if (list is! List) return {};
    return list.map((e) => e.toString()).toSet();
  }

  Future<void> markViewed(String discoveryId) async {
    final viewed = await readViewedIds();
    viewed.add(discoveryId);
    final trimmed = viewed.length > 200
        ? viewed.skip(viewed.length - 200)
        : viewed;
    await _prefs.writeJsonMap(_viewedKey, {'ids': trimmed.toList()});
  }

  Future<DailyDiscoveryBaseline?> readBaseline() async {
    final raw = await _prefs.readJsonMap(_baselineKey);
    return DailyDiscoveryBaseline.fromJson(raw);
  }

  Future<void> writeBaseline(DailyDiscoveryBaseline baseline) async {
    await _prefs.writeJsonMap(_baselineKey, baseline.toJson());
  }

  Future<DailyDiscovery?> readPending() async {
    final raw = await _prefs.readJsonMap(_pendingKey);
    return DailyDiscovery.fromJson(raw);
  }

  Future<void> writePending(DailyDiscovery? discovery) async {
    if (discovery == null) {
      await _prefs.writeJsonMap(_pendingKey, {});
      return;
    }
    await _prefs.writeJsonMap(_pendingKey, discovery.toJson());
  }
}