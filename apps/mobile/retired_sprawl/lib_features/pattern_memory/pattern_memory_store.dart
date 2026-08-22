import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_engine.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists the single active pattern memory thread plus a capped history.
class PatternMemoryStore {
  PatternMemoryStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _activeKey = 'patternMemoryActive';
  static const _historyKey = 'patternMemoryHistory';
  static const _historyMax = 20;

  static const PatternMemoryEngine _engine = PatternMemoryEngine();

  Future<PatternMemory?> loadActive() async {
    final raw = await _prefs.readMap(_activeKey);
    return PatternMemory.fromJson(raw);
  }

  Future<void> saveActive(PatternMemory memory) async {
    await _prefs.writeMap(_activeKey, memory.toJson());
  }

  Future<List<PatternMemory>> loadHistory({int limit = 20}) async {
    final raw = await _prefs.readMap(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    final memories = list
        .map(
          (e) => PatternMemory.fromJson(
            e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
          ),
        )
        .whereType<PatternMemory>()
        .toList();
    return memories.take(limit).toList();
  }

  Future<void> appendToHistory(PatternMemory memory) async {
    final history = await loadHistory();
    final next = [
      memory,
      ...history.where((h) => h.id != memory.id),
    ].take(_historyMax).toList();
    await _prefs.writeMap(_historyKey, {
      'items': next.map((m) => m.toJson()).toList(),
    });
  }

  Future<void> clear() async {
    await _prefs.writeMap(_activeKey, {});
    await _prefs.writeMap(_historyKey, {'items': []});
  }

  /// Applies one check-in answer to the active memory and saves it.
  ///
  /// Creates a new memory thread when none exists, or when the active thread
  /// belongs to a different pattern.
  Future<PatternMemory> applyUpdate(
    PatternMemoryUpdate update, {
    required String patternTitle,
  }) async {
    final existing = await loadActive();
    final title = patternTitle.trim();
    final samePattern =
        existing != null &&
        title.isNotEmpty &&
        existing.patternTitle.trim().toLowerCase() == title.toLowerCase();
    final previous = samePattern ? existing : null;

    // Starting a memory for a different pattern: keep the old one in history.
    if (existing != null && !samePattern) {
      await appendToHistory(existing);
    }

    final updated = _engine.apply(previous, update, patternTitle: patternTitle);
    await saveActive(updated);
    return updated;
  }
}