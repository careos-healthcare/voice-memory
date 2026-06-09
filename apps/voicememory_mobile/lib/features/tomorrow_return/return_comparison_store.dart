import '../../storage/mobile_prefs_store.dart';
import 'return_comparison_model.dart';

/// Persists the latest return comparison for the Patterns tab.
class ReturnComparisonStore {
  ReturnComparisonStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'returnComparisonLatest';
  static const _historyKey = 'returnComparisonHistory';
  static const _historyMax = 14;

  Future<ReturnComparison?> read() async {
    final raw = await _prefs.readMap(_key);
    return ReturnComparison.fromJson(raw);
  }

  Future<List<ReturnComparison>> readRecent() async {
    final raw = await _prefs.readMap(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .map((e) => ReturnComparison.fromJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
            ))
        .whereType<ReturnComparison>()
        .toList();
  }

  Future<void> write(ReturnComparison? comparison) async {
    if (comparison == null) {
      await _prefs.writeMap(_key, {});
      return;
    }
    await _prefs.writeMap(_key, comparison.toJson());
    await _appendHistory(comparison);
  }

  Future<void> _appendHistory(ReturnComparison comparison) async {
    final recent = await readRecent();
    final next = [comparison, ...recent].take(_historyMax).toList();
    await _prefs.writeMap(_historyKey, {
      'items': next.map((c) => c.toJson()).toList(),
    });
  }
}
