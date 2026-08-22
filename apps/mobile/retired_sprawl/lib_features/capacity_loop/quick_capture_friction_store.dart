import 'package:archiveme_mobile/features/capacity_loop/quick_capture_friction_models.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Local-only quick capture friction persistence — fixed response ids only.
class QuickCaptureFrictionStore {
  QuickCaptureFrictionStore(this._prefs);

  static const prefsKey = 'archiveQuickCaptureFrictionCheck';

  final MobilePrefsStore _prefs;

  static QuickCaptureFrictionRecord? _cached;
  static bool _loaded = false;

  static QuickCaptureFrictionRecord? get cached => _cached;

  static QuickCaptureFrictionStore instance() =>
      QuickCaptureFrictionStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadRecord();
    _loaded = true;
  }

  Future<QuickCaptureFrictionRecord?> loadRecord() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return null;
    return QuickCaptureFrictionRecord.fromJson(raw);
  }

  Future<void> saveAnswered({
    required String responseId,
    required String relatedEntryId,
  }) async {
    if (responseId.isEmpty) return;
    final now = DateTime.now().toUtc();
    final existing = _cached;
    final record = QuickCaptureFrictionRecord(
      responseId: responseId,
      source: QuickCaptureFrictionSource.quickYesCapture,
      relatedEntryId: relatedEntryId,
      status: QuickCaptureFrictionStatus.answered,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _persist(record);
  }

  Future<void> saveSkipped({required String relatedEntryId}) async {
    final now = DateTime.now().toUtc();
    final existing = _cached;
    final record = QuickCaptureFrictionRecord(
      responseId: '',
      source: QuickCaptureFrictionSource.quickYesCapture,
      relatedEntryId: relatedEntryId,
      status: QuickCaptureFrictionStatus.skipped,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _persist(record);
  }

  Future<void> _persist(QuickCaptureFrictionRecord record) async {
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
  static void seedForTest(QuickCaptureFrictionRecord? record) {
    _cached = record;
    _loaded = true;
  }
}