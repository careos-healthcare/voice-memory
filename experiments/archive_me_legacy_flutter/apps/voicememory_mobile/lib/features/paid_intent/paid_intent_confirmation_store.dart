import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'paid_intent_confirmation_models.dart';

/// Local-only paid intent confirmation — fixed response ids, no journal text.
class PaidIntentConfirmationStore {
  PaidIntentConfirmationStore(this._prefs);

  static const prefsKey = 'archivePaidIntentConfirmation';

  final MobilePrefsStore _prefs;

  static PaidIntentConfirmationRecord? _cached;
  static bool _loaded = false;

  static PaidIntentConfirmationRecord? get cached => _cached;

  static PaidIntentConfirmationStore instance() =>
      PaidIntentConfirmationStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadRecord();
    _loaded = true;
  }

  Future<PaidIntentConfirmationRecord?> loadRecord() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return null;
    return PaidIntentConfirmationRecord.fromJson(raw);
  }

  Future<void> saveAnswered({
    required String responseId,
    required PaidIntentValueSignalsAtResponse valueSignals,
  }) async {
    if (responseId.isEmpty) return;
    final now = DateTime.now().toUtc();
    final existing = _cached;
    final record = PaidIntentConfirmationRecord(
      responseId: responseId,
      source: PaidIntentConfirmationSource.capacityBetaValueSignal,
      status: PaidIntentConfirmationStatus.answered,
      valueSignalsAtResponse: valueSignals,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _persist(record);
  }

  Future<void> saveSkipped({
    required PaidIntentValueSignalsAtResponse valueSignals,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = _cached;
    final record = PaidIntentConfirmationRecord(
      responseId: '',
      source: PaidIntentConfirmationSource.capacityBetaValueSignal,
      status: PaidIntentConfirmationStatus.skipped,
      valueSignalsAtResponse: valueSignals,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _persist(record);
  }

  Future<void> _persist(PaidIntentConfirmationRecord record) async {
    await _prefs.writeJsonMap(prefsKey, record.toJson());
    _cached = record;
    _loaded = true;
  }

  static Future<void> resetForTest() async {
    _cached = null;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {});
  }

  @visibleForTesting
  static void seedForTest(PaidIntentConfirmationRecord? record) {
    _cached = record;
    _loaded = true;
  }
}
