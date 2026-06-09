import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'routine_anchor_model.dart';

/// Local store for routine anchors, keyed by a check-in's target date.
///
/// Anchors are planning labels only — nothing here schedules a real reminder.
class RoutineAnchorStore {
  RoutineAnchorStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'routineAnchors';
  static const _byDateField = 'byDate';
  static const _latestField = 'latest';
  static const _maxDates = 60;

  static RoutineAnchorStore instance() =>
      RoutineAnchorStore(AppServices.instance.prefs);

  Future<void> saveForDate(String dateKey, RoutineAnchor anchor) async {
    if (dateKey.trim().isEmpty) return;
    final raw = await _prefs.readMap(_key) ?? <String, dynamic>{};
    final byDate = _byDate(raw);
    byDate[dateKey] = anchor.toJson();
    final capped = _capByDate(byDate);
    await _prefs.writeMap(_key, {
      _byDateField: capped,
      _latestField: anchor.toJson(),
    });
  }

  Future<RoutineAnchor?> loadForDate(String dateKey) async {
    final raw = await _prefs.readMap(_key);
    if (raw == null) return null;
    final byDate = _byDate(raw);
    final entry = byDate[dateKey];
    return RoutineAnchor.fromJson(_asMap(entry));
  }

  Future<RoutineAnchor?> loadLatest() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null) return null;
    return RoutineAnchor.fromJson(_asMap(raw[_latestField]));
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }

  Map<String, dynamic> _byDate(Map<String, dynamic> raw) {
    final value = raw[_byDateField];
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  /// Keeps only the newest [_maxDates] date keys (lexicographic = chronological
  /// for yyyy-MM-dd keys) so the map cannot grow without bound.
  Map<String, dynamic> _capByDate(Map<String, dynamic> byDate) {
    if (byDate.length <= _maxDates) return byDate;
    final keys = byDate.keys.toList()..sort();
    final keep = keys.sublist(keys.length - _maxDates);
    return {for (final k in keep) k: byDate[k]};
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
