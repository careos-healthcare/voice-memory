import 'package:archiveme_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/features/post_save_insight/post_save_insight_models.dart';

/// Alternate next-recording prompts for a selected signal.
class NextEvidencePromptEngine {
  const NextEvidencePromptEngine();

  List<String> promptsFor({
    required PostSaveInsightSignal signal,
    required FirstSessionPattern pattern,
    int rotation = 0,
  }) {
    final primary = signal.recordNextQuestion.trim();
    final cat = firstSessionPatternCategoryFromIdOrFallback(signal.categoryId);
    final alts = _alternatesFor(cat, pattern);
    final pool = <String>[if (primary.isNotEmpty) primary, ...alts];
    final deduped = <String>[];
    for (final p in pool) {
      if (p.trim().isEmpty) continue;
      if (deduped.any((d) => d.toLowerCase() == p.toLowerCase())) continue;
      deduped.add(p);
    }
    if (deduped.isEmpty) {
      return const ['What stood out most in this moment?'];
    }
    if (deduped.length == 1) return deduped;
    final start = rotation % deduped.length;
    return [
      deduped[start],
      deduped[(start + 1) % deduped.length],
      if (deduped.length > 2) deduped[(start + 2) % deduped.length],
    ];
  }

  List<String> _alternatesFor(
    FirstSessionPatternCategory cat,
    FirstSessionPattern pattern,
  ) {
    return switch (cat) {
      FirstSessionPatternCategory.responsibility => const [
        'When did you next feel pressure to say yes?',
        'What happened before you felt responsible again?',
        'What would have made this feel lighter?',
      ],
      FirstSessionPatternCategory.worry => const [
        'When did the same worry show up again?',
        'What triggered it this time?',
        'What helped even briefly?',
      ],
      FirstSessionPatternCategory.selfDoubt => const [
        'When did you last feel enough without proving anything?',
        'What were you comparing yourself to?',
        'What would enough look like here?',
      ],
      FirstSessionPatternCategory.avoidance => const [
        'What did you avoid saying directly?',
        'What made starting feel hard?',
        'What would make starting easier?',
      ],
      FirstSessionPatternCategory.relationship => const [
        'What did you want to say but did not?',
        'When did tension show up again?',
        'What felt unresolved after?',
      ],
      FirstSessionPatternCategory.burnout => const [
        'What would you drop if you had more energy?',
        'When did you say yes while tired?',
        'What rest did you skip?',
      ],
      FirstSessionPatternCategory.lighter => const [
        'What felt lighter — and what was different before?',
        'When did ease show up again?',
        'What made this moment stand out?',
      ],
      FirstSessionPatternCategory.fallback => [
        'What part of today might be worth recording again tomorrow?',
        if (pattern.watchForText.isNotEmpty) 'Notice ${pattern.watchForText}.',
      ],
    };
  }
}