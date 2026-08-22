import 'package:archiveme_mobile/features/beta_decision/beta_decision_model.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Local-only beta tester outcome log — metadata signals, no transcript text.
class BetaTesterOutcomeStore {
  BetaTesterOutcomeStore(this._prefs);

  static const prefsKey = 'betaTesterOutcomes_v1';

  final MobilePrefsStore _prefs;

  static final List<BetaTesterOutcome> _cached = [];
  static bool _loaded = false;

  static List<BetaTesterOutcome> get allOutcomes =>
      List<BetaTesterOutcome>.unmodifiable(_cached);

  static int get count => _cached.length;

  static BetaTesterOutcomeStore instance() =>
      BetaTesterOutcomeStore(AppServices.instance.prefs);

  static BetaTesterOutcomeStore forPrefs(MobilePrefsStore prefs) =>
      BetaTesterOutcomeStore(prefs);

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (_loaded) return;
    final store = instance();
    final raw = await store._prefs.readMap(prefsKey);
    _hydrateFromRaw(raw);
    _loaded = true;
  }

  static void _hydrateFromRaw(Map<String, dynamic>? raw) {
    _cached.clear();
    if (raw == null || raw.isEmpty) return;
    final outcomes = raw['outcomes'];
    if (outcomes is! List) return;
    for (final entry in outcomes) {
      if (entry is Map<String, dynamic>) {
        _cached.add(BetaTesterOutcome.fromJson(entry));
      } else if (entry is Map) {
        _cached.add(
          BetaTesterOutcome.fromJson(Map<String, dynamic>.from(entry)),
        );
      }
    }
  }

  static String suggestNextTesterId() {
    var max = 0;
    for (final outcome in _cached) {
      final match = RegExp(r'^tester-(\d+)$').firstMatch(outcome.testerId);
      if (match == null) continue;
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value > max) max = value;
    }
    return 'tester-${max + 1}';
  }

  Future<void> addOutcome(BetaTesterOutcome outcome) async {
    _cached.add(
      BetaTesterOutcome(
        testerId: outcome.testerId,
        signals: Set<BetaDecisionSignal>.from(outcome.signals),
        notes: outcome.notes,
        loggedAt: outcome.loggedAt ?? DateTime.now().toUtc(),
      ),
    );
    _loaded = true;
    await _persist();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _cached.length) return;
    _cached.removeAt(index);
    _loaded = true;
    await _persist();
  }

  Future<void> clearAll() async {
    _cached.clear();
    _loaded = true;
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.writeMap(prefsKey, {
      'outcomes': _cached.map((outcome) => outcome.toJson()).toList(),
    });
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    _cached.clear();
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeMap(prefsKey, {});
  }
}