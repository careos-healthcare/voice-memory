import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'capacity_boundary_response_models.dart';

/// Local-only boundary response selection — template id and timestamps only.
class CapacityBoundaryResponseStore {
  CapacityBoundaryResponseStore(this._prefs);

  static const prefsKey = 'archiveCapacityBoundaryResponse';

  final MobilePrefsStore _prefs;

  static CapacityBoundaryResponseSelection? _cached;
  static bool _loaded = false;

  static CapacityBoundaryResponseSelection? get cached => _cached;

  static CapacityBoundaryResponseStore instance() =>
      CapacityBoundaryResponseStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadSelection();
    _loaded = true;
  }

  Future<CapacityBoundaryResponseSelection?> loadSelection() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return null;
    return CapacityBoundaryResponseSelection.fromJson(raw);
  }

  Future<void> saveSelection(String responseId) async {
    if (responseId.isEmpty) return;
    final now = DateTime.now().toUtc();
    final record = CapacityBoundaryResponseSelection(
      responseId: responseId,
      selectedAt: now,
      dismissed: false,
    );
    await _persist(record);
  }

  Future<void> saveDismissed() async {
    final existing = _cached;
    final now = DateTime.now().toUtc();
    final record = CapacityBoundaryResponseSelection(
      responseId: existing?.responseId ?? '',
      selectedAt: existing?.selectedAt ?? now,
      lastCopiedAt: existing?.lastCopiedAt,
      dismissed: true,
    );
    await _persist(record);
  }

  Future<void> recordCopied() async {
    final existing = _cached;
    if (existing == null || !existing.hasSelection) return;
    await _persist(existing.copyWith(lastCopiedAt: DateTime.now().toUtc()));
  }

  Future<void> _persist(CapacityBoundaryResponseSelection record) async {
    await _prefs.writeJsonMap(prefsKey, record.toJson());
    _cached = record;
    _loaded = true;
  }

  static Future<void> clearAll() async {
    if (!AppServices.isInitialized) {
      _cached = null;
      _loaded = true;
      return;
    }
    await instance()._prefs.writeJsonMap(prefsKey, {});
    _cached = null;
    _loaded = true;
  }

  @visibleForTesting
  static void resetForTest() {
    _cached = null;
    _loaded = false;
  }

  @visibleForTesting
  static void seedForTest(CapacityBoundaryResponseSelection? selection) {
    _cached = selection;
    _loaded = true;
  }
}
