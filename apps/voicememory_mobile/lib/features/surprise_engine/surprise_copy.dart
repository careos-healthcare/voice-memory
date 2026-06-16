import '../living_archive/living_archive_copy.dart';
import 'surprise_models.dart';

/// Copy for Surprise Pipeline V1 — reflective, curiosity-first.
abstract class SurpriseCopy {
  SurpriseCopy._();

  static const String sectionHeadline = 'YOUR ARCHIVE NOTICED SOMETHING';

  static const String promptQuestion = 'What surprised the archive?';

  static String headlineFor({
    required SurpriseType type,
    String? beliefSnippet,
    String? themeLabel,
    String? priorThemeLabel,
    String? chapterTitle,
  }) {
    return switch (type) {
      SurpriseType.archiveChangedMind =>
        priorThemeLabel != null
            ? 'The archive is less convinced that $priorThemeLabel is your biggest problem.'
            : 'The archive changed its mind about what your recordings emphasize.',
      SurpriseType.confidenceChangedSharply => 'This belief is weakening.',
      SurpriseType.newContradiction =>
        'Two of your reflections no longer line up the way they used to.',
      SurpriseType.unexpectedThemeRise =>
        themeLabel != null
            ? 'This pattern appeared unexpectedly — you keep returning to $themeLabel.'
            : 'This pattern appeared unexpectedly.',
      SurpriseType.themeDisappearance =>
        themeLabel != null
            ? 'You mention $themeLabel far less than before.'
            : 'Something you used to return to has gone quiet in recent recordings.',
      SurpriseType.newLifeChapter =>
        chapterTitle != null
            ? 'Your archive grouped recent reflections into “$chapterTitle”.'
            : 'A new life chapter may be opening in your archive.',
      SurpriseType.emotionalShift =>
        'The emotional weight in your recent recordings shifted.',
    };
  }

  static String whyFor(SurpriseType type) {
    return switch (type) {
      SurpriseType.archiveChangedMind =>
        'Newer recordings outweighed what the archive assumed from earlier evidence.',
      SurpriseType.confidenceChangedSharply =>
        'Language tied to your working story moved enough that the archive adjusted how strongly it reads.',
      SurpriseType.newContradiction =>
        'Contradictions often mark competing needs — both entries are still in your archive.',
      SurpriseType.unexpectedThemeRise =>
        'A spike in language often precedes a conscious decision — the archive flagged it early.',
      SurpriseType.themeDisappearance =>
        'Declining language can mean relief, avoidance, or a shift in focus — your recordings are the evidence.',
      SurpriseType.newLifeChapter =>
        'Chapter transitions mark stretches of life where your language clusters.',
      SurpriseType.emotionalShift =>
        'Intensity shifts are measured from your own words — not an outside mood score.',
    };
  }

  static int priorityIndex(SurpriseType type) => type.index;

  static SurpriseType? fromDailyDiscoveryType(String? name) {
    if (name == null) return null;
    return switch (name) {
      'contradictionEmerging' => SurpriseType.newContradiction,
      'themeSpike' => SurpriseType.unexpectedThemeRise,
      'themeDecline' => SurpriseType.themeDisappearance,
      'chapterTransition' => SurpriseType.newLifeChapter,
      'emotionalShift' => SurpriseType.emotionalShift,
      'beliefWeakening' => SurpriseType.confidenceChangedSharply,
      _ => null,
    };
  }

  static String themeLabelFromKey(String key) {
    const labels = {
      'approval': 'approval',
      'work': 'work',
      'career': 'work',
      'confidence': 'confidence',
      'stress': 'stress',
      'relationship': 'relationships',
      'relationships': 'relationships',
    };
    return labels[key] ?? key;
  }

  static String workDominanceHeadline() =>
      LivingArchiveCopy.themeDominanceWrongHeadline(
        priorThemeKey: 'work',
        currentThemeKey: 'relationship',
      );
}
