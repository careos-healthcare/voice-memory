import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'capacity_beta_mission_models.dart';

/// Local mission metadata — timestamps and dismiss only.
class CapacityBetaMissionStore {
  CapacityBetaMissionStore(this._prefs);

  static const prefsKey = 'archiveCapacityBetaMission';

  final MobilePrefsStore _prefs;

  static CapacityBetaMissionRecord _cached = CapacityBetaMissionRecord.empty;
  static bool _loaded = false;

  static CapacityBetaMissionRecord get cached => _cached;

  static CapacityBetaMissionStore instance() =>
      CapacityBetaMissionStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadRecord();
    _loaded = true;
  }

  Future<CapacityBetaMissionRecord> loadRecord() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return CapacityBetaMissionRecord.empty;
    return CapacityBetaMissionRecord.fromJson(raw) ??
        CapacityBetaMissionRecord.empty;
  }

  Future<void> markStarted() async {
    if (_cached.startedAt != null) return;
    final now = DateTime.now().toUtc();
    await _persist(_cached.copyWith(startedAt: now));
  }

  Future<void> markCompleted() async {
    if (_cached.completedAt != null) return;
    final now = DateTime.now().toUtc();
    await _persist(
      _cached.copyWith(
        startedAt: _cached.startedAt ?? now,
        completedAt: now,
      ),
    );
  }

  Future<void> dismiss() async {
    await _persist(_cached.copyWith(dismissed: true));
  }

  Future<void> _persist(CapacityBetaMissionRecord record) async {
    _cached = record;
    await _prefs.writeJsonMap(prefsKey, record.toJson());
  }

  static void resetForTest() {
    _cached = CapacityBetaMissionRecord.empty;
    _loaded = false;
  }
}
