import 'package:archiveme_mobile/features/capacity_loop/capacity_activation_fit_models.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Local-only activation fit persistence — fixed response ids only.
class CapacityActivationFitStore {
  CapacityActivationFitStore(this._prefs);

  static const prefsKey = 'archiveCapacityActivationFit';

  final MobilePrefsStore _prefs;

  static CapacityActivationFitRecord? _cached;
  static bool _loaded = false;

  static CapacityActivationFitRecord? get cached => _cached;

  static CapacityActivationFitStore instance() =>
      CapacityActivationFitStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadRecord();
    _loaded = true;
  }

  Future<CapacityActivationFitRecord?> loadRecord() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return null;
    return CapacityActivationFitRecord.fromJson(raw);
  }

  Future<void> saveAnswered({
    required String responseId,
    required int activationEntryCount,
  }) async {
    if (responseId.isEmpty) return;
    final now = DateTime.now().toUtc();
    final existing = _cached;
    final record = CapacityActivationFitRecord(
      responseId: responseId,
      source: CapacityActivationFitSource.capacityLoopActivation,
      activationEntryCount: activationEntryCount,
      status: CapacityActivationFitStatus.answered,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _persist(record);
  }

  Future<void> saveSkipped({required int activationEntryCount}) async {
    final now = DateTime.now().toUtc();
    final existing = _cached;
    final record = CapacityActivationFitRecord(
      responseId: '',
      source: CapacityActivationFitSource.capacityLoopActivation,
      activationEntryCount: activationEntryCount,
      status: CapacityActivationFitStatus.skipped,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _persist(record);
  }

  Future<void> _persist(CapacityActivationFitRecord record) async {
    await _prefs.writeJsonMap(prefsKey, record.toJson());
    _cached = record;
    _loaded = true;
  }

  static bool get hasCompleteRecord => _cached?.isComplete ?? false;

  static Future<void> clearAll() async {
    _cached = null;
    _loaded = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _cached = null;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {});
  }

  @visibleForTesting
  static void seedForTest(CapacityActivationFitRecord? record) {
    _cached = record;
    _loaded = true;
  }
}