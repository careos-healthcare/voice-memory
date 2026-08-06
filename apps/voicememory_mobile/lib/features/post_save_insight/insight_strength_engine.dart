import '../first_session/first_session_pattern_model.dart';
import 'insight_strength_model.dart';

/// Derives conservative insight strength from pattern evidence — no AI scores.
class InsightStrengthEngine {
  const InsightStrengthEngine();

  InsightStrength build({
    required FirstSessionPattern pattern,
    required PostSaveInsightSignalContext signal,
    int reflectionCount = 1,
    bool categoryRepeated = false,
  }) {
    final chips = _evidenceChips(pattern, signal);
    final label = _labelFor(
      chipCount: chips.length,
      reflectionCount: reflectionCount,
      categoryRepeated: categoryRepeated,
      confidenceScore: pattern.confidenceScore,
    );
    return InsightStrength(
      label: label,
      whySuggested: _whySuggested(pattern, signal, chips),
      evidenceChips: chips,
    );
  }

  List<String> _evidenceChips(
    FirstSessionPattern pattern,
    PostSaveInsightSignalContext signal,
  ) {
    final raw = <String>[
      ...pattern.chips,
      ...pattern.matchedPhrases,
      if (signal.categoryId == pattern.categoryId) ...pattern.chips,
    ];
    final seen = <String>{};
    final out = <String>[];
    for (final c in raw) {
      final t = c.trim();
      if (t.isEmpty || seen.contains(t.toLowerCase())) continue;
      seen.add(t.toLowerCase());
      out.add(t.length > 36 ? '${t.substring(0, 33)}…' : t);
      if (out.length >= 3) break;
    }
    if (out.isEmpty && pattern.whyNoticed.trim().isNotEmpty) {
      final why = pattern.whyNoticed.trim();
      out.add(why.length > 36 ? '${why.substring(0, 33)}…' : why);
    }
    return out;
  }

  String _whySuggested(
    FirstSessionPattern pattern,
    PostSaveInsightSignalContext signal,
    List<String> chips,
  ) {
    if (chips.isNotEmpty) {
      final joined = chips.take(3).join(', ');
      return 'You mentioned $joined.';
    }
    final why = signal.explanation.trim().isNotEmpty
        ? signal.explanation.trim()
        : pattern.whyNoticed.trim();
    if (why.isNotEmpty) return why;
    return 'ArchiveMe noticed a possible theme in how you described this moment.';
  }

  InsightStrengthLabel _labelFor({
    required int chipCount,
    required int reflectionCount,
    required bool categoryRepeated,
    required double confidenceScore,
  }) {
    if (reflectionCount >= 4 &&
        chipCount >= 3 &&
        confidenceScore >= 0.55 &&
        categoryRepeated) {
      return InsightStrengthLabel.strongPattern;
    }
    if (reflectionCount >= 3 && chipCount >= 2) {
      return InsightStrengthLabel.gettingClearer;
    }
    if (categoryRepeated || (reflectionCount >= 2 && chipCount >= 2)) {
      return InsightStrengthLabel.possibleRepeat;
    }
    return InsightStrengthLabel.earlySignal;
  }
}

/// Minimal signal context for strength scoring.
class PostSaveInsightSignalContext {
  const PostSaveInsightSignalContext({
    required this.categoryId,
    required this.explanation,
  });

  final String categoryId;
  final String explanation;
}
