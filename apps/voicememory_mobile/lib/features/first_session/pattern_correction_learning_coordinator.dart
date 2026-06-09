import '../../services/app_services.dart';
import 'first_session_pattern_category.dart';
import 'first_session_pattern_model.dart';
import 'pattern_correction_learning_model.dart';
import 'pattern_correction_learning_store.dart';

/// Records corrections and supplies category boosts for the pattern engine.
abstract final class PatternCorrectionLearningCoordinator {
  PatternCorrectionLearningCoordinator._();

  static const double categoryBoostAmount = 0.12;
  static const int _boostLookback = 10;
  static const int reflectionSnippetMaxLength = 160;

  static PatternCorrectionLearningStore _store() =>
      PatternCorrectionLearningStore(AppServices.instance.prefs);

  static Future<PatternCorrectionLearning> recordFirstSessionCorrection({
    required FirstSessionPattern originalPattern,
    required FirstSessionPattern correctedPattern,
    required String reflectionText,
  }) async {
    final learning = PatternCorrectionLearning(
      id: 'pcl_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      originalTitle: originalPattern.title,
      correctedTitle: correctedPattern.title,
      originalCategoryId: originalPattern.categoryId,
      correctedCategoryId: correctedPattern.categoryId,
      reflectionSnippet: _snippet(reflectionText),
      matchedPhrases: originalPattern.matchedPhrases.take(4).toList(),
      correctedWatchForText: correctedPattern.watchForText,
      source: PatternCorrectionLearningSource.firstSession,
    );
    await _store().saveLearning(learning);
    return learning;
  }

  static Future<PatternCorrectionLearning?> recentCorrectionForReflection(
    String reflectionText,
  ) async {
    final needle = _normalize(reflectionText);
    if (needle.isEmpty) return null;
    for (final item in await _store().loadRecent()) {
      final hay = _normalize(item.reflectionSnippet);
      if (hay.isEmpty) continue;
      if (needle.contains(hay) || hay.contains(needle)) return item;
    }
    return null;
  }

  static Future<Map<FirstSessionPatternCategory, double>>
      preferredCategoryBoosts() async {
    final recent = await _store().loadRecent(limit: _boostLookback);
    final counts = <String, int>{};
    for (final item in recent) {
      final id = item.correctedCategoryId;
      if (id.isEmpty ||
          id == FirstSessionPatternCategory.fallback.id ||
          id == FirstSessionPatternCategory.lighter.id) {
        continue;
      }
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final boosts = <FirstSessionPatternCategory, double>{};
    for (final entry in counts.entries) {
      final cat = firstSessionPatternCategoryFromId(entry.key);
      if (cat == null) continue;
      boosts[cat] = categoryBoostAmount;
    }
    return boosts;
  }

  static Future<void> markUsedForNextPrompt(String id) async {
    await _store().markUsedForNextPrompt(id);
  }

  static Future<PatternCorrectionLearningSummary> buildDeveloperSummary() async {
    final all = await _store().readAll();
    final used = all.where((e) => e.usedForNextPrompt).length;
    final counts = <String, int>{};
    final titleCounts = <String, int>{};
    for (final item in all) {
      counts[item.correctedCategoryId] =
          (counts[item.correctedCategoryId] ?? 0) + 1;
      titleCounts[item.correctedTitle] =
          (titleCounts[item.correctedTitle] ?? 0) + 1;
    }
    var topCategory = '';
    var topCategoryCount = 0;
    for (final e in counts.entries) {
      if (e.value > topCategoryCount) {
        topCategory = e.key;
        topCategoryCount = e.value;
      }
    }
    var topTitle = '';
    var topTitleCount = 0;
    for (final e in titleCounts.entries) {
      if (e.value > topTitleCount) {
        topTitle = e.key;
        topTitleCount = e.value;
      }
    }
    return PatternCorrectionLearningSummary(
      totalLearned: all.length,
      usedForNextPromptCount: used,
      mostCorrectedCategoryId: topCategory,
      mostCorrectedTitle: topTitle,
      recent: all.take(8).toList(),
    );
  }

  static String _snippet(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= reflectionSnippetMaxLength) return trimmed;
    return '${trimmed.substring(0, reflectionSnippetMaxLength - 1)}…';
  }

  static String _normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
