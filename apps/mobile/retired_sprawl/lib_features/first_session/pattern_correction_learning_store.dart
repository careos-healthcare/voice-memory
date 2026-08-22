import 'package:archiveme_mobile/features/first_session/pattern_correction_learning_model.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists pattern corrections for next-time matching.
class PatternCorrectionLearningStore {
  PatternCorrectionLearningStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'pattern_correction_learning_items';
  static const int maxItems = 100;

  Future<List<PatternCorrectionLearning>> readAll() async {
    final map = await _prefs.readMap(_key);
    final raw = map?['items'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map(
          (e) =>
              PatternCorrectionLearning.fromJson(Map<String, dynamic>.from(e)),
        )
        .whereType<PatternCorrectionLearning>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveLearning(PatternCorrectionLearning learning) async {
    final items = await readAll();
    items.insert(0, learning);
    final capped = items.length > maxItems ? items.sublist(0, maxItems) : items;
    await _write(capped);
  }

  Future<List<PatternCorrectionLearning>> loadRecent({int limit = 20}) async {
    final all = await readAll();
    if (all.length <= limit) return all;
    return all.sublist(0, limit);
  }

  Future<List<PatternCorrectionLearning>> loadByCorrectedCategory(
    String categoryId,
  ) async {
    if (categoryId.isEmpty) return const [];
    return (await readAll())
        .where((e) => e.correctedCategoryId == categoryId)
        .toList();
  }

  Future<void> markUsedForNextPrompt(String id) async {
    final items = await readAll();
    var changed = false;
    for (var i = 0; i < items.length; i++) {
      if (items[i].id == id) {
        items[i] = items[i].copyWith(usedForNextPrompt: true);
        changed = true;
        break;
      }
    }
    if (changed) await _write(items);
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {'items': <Map<String, dynamic>>[]});
  }

  Future<void> _write(List<PatternCorrectionLearning> items) async {
    await _prefs.writeMap(_key, {
      'items': items.map((e) => e.toJson()).toList(),
    });
  }
}