import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'key_moment_model.dart';

/// Local store for the Key Moments timeline.
///
/// Newest first, capped at [_maxMoments]. Stored in its own prefs key so the
/// rest of the schema is untouched.
class KeyMomentStore {
  KeyMomentStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'keyMoments';
  static const _maxMoments = 500;

  static KeyMomentStore instance() =>
      KeyMomentStore(AppServices.instance.prefs);

  Future<void> save(KeyMoment moment) async {
    final all = await loadAll();
    final next = <KeyMoment>[moment, ...all.where((m) => m.id != moment.id)];
    next.sort((a, b) => b.date.compareTo(a.date));
    final capped = next.take(_maxMoments).toList();
    await _prefs.writeMap(_key, {
      'items': capped.map((m) => m.toJson()).toList(),
    });
  }

  Future<List<KeyMoment>> loadAll() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    final moments = <KeyMoment>[];
    for (final e in list) {
      final map = e is Map<String, dynamic>
          ? e
          : (e is Map ? Map<String, dynamic>.from(e) : null);
      final moment = KeyMoment.fromJson(map);
      if (moment != null) moments.add(moment);
    }
    moments.sort((a, b) => b.date.compareTo(a.date));
    return moments;
  }

  Future<List<KeyMoment>> loadByDate(DateTime date) async {
    final key = _dayKey(date);
    final all = await loadAll();
    return all.where((m) => m.dayKey == key).toList();
  }

  Future<List<KeyMoment>> loadRecent({int limit = 20}) async {
    final all = await loadAll();
    return all.take(limit).toList();
  }

  Future<KeyMoment?> loadById(String id) async {
    final all = await loadAll();
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<List<KeyMoment>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final all = await loadAll();
    return all.where((m) {
      final haystack = <String>[
        m.originalText,
        m.shortSummary,
        m.title,
        m.patternTitle ?? '',
        m.tags.join(' '),
        m.dayKey,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {'items': []});
  }

  String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
