/// How specific tomorrow's watch-for prompt is.
enum WatchForPromptStrength { low, medium, high }

extension WatchForPromptStrengthIds on WatchForPromptStrength {
  String get id => name;
}

WatchForPromptStrength? watchForPromptStrengthFromId(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  for (final s in WatchForPromptStrength.values) {
    if (s.id == raw) return s;
  }
  return null;
}

/// Tone ids for tomorrow's check-in question variants.
abstract class WatchForQuestionVariantId {
  WatchForQuestionVariantId._();

  static const gentle = 'gentle';
  static const sharper = 'sharper';
  static const practical = 'practical';
}

/// One tone option for tomorrow's check-in question.
class WatchForQuestionVariant {
  const WatchForQuestionVariant({
    required this.id,
    required this.label,
    required this.question,
    required this.prompt,
  });

  /// gentle | sharper | practical
  final String id;
  final String label;
  final String question;
  final String prompt;
}

/// Category-specific tomorrow watch-for copy.
class WatchForPrompt {
  const WatchForPrompt({
    required this.id,
    required this.createdAt,
    required this.patternTitle,
    required this.shortPrompt,
    required this.specificPrompt,
    required this.checkInQuestion,
    required this.chips,
    required this.strength,
    this.situationHint = '',
    this.emotionalHint = '',
    this.questionVariants = const [],
    this.selectedVariantId,
  });

  final String id;
  final DateTime createdAt;
  final String patternTitle;
  final String shortPrompt;
  final String specificPrompt;
  final String situationHint;
  final String emotionalHint;
  final String checkInQuestion;
  final List<String> chips;
  final WatchForPromptStrength strength;
  final List<WatchForQuestionVariant> questionVariants;
  final String? selectedVariantId;

  /// The variant matching [selectedVariantId], or the first variant if unset.
  WatchForQuestionVariant? get selectedVariant {
    if (questionVariants.isEmpty) return null;
    final id = selectedVariantId;
    if (id != null) {
      for (final v in questionVariants) {
        if (v.id == id) return v;
      }
    }
    return questionVariants.first;
  }

  /// Returns a copy whose question + prompt come from [variantId].
  WatchForPrompt withSelectedVariant(String variantId) {
    WatchForQuestionVariant? match;
    for (final v in questionVariants) {
      if (v.id == variantId) {
        match = v;
        break;
      }
    }
    if (match == null) return this;
    return WatchForPrompt(
      id: id,
      createdAt: createdAt,
      patternTitle: patternTitle,
      shortPrompt: shortPrompt,
      specificPrompt: match.prompt,
      checkInQuestion: match.question,
      chips: chips,
      strength: strength,
      situationHint: situationHint,
      emotionalHint: emotionalHint,
      questionVariants: questionVariants,
      selectedVariantId: variantId,
    );
  }
}
