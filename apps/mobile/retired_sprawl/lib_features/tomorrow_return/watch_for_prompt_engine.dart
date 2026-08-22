import 'package:archiveme_mobile/features/feedback/archive_feedback_model.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_summary_engine.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_prompt_model.dart';
import 'package:archiveme_mobile/features/trial/hook_rescue_decision_model.dart';

/// Builds specific tomorrow watch-for prompts from a first-session pattern.
class WatchForPromptEngine {
  const WatchForPromptEngine();

  WatchForPrompt build({
    required FirstSessionPattern pattern,
    String reflectionText = '',
    DateTime? now,
    bool sharper = false,
    HookRescueIntensity? intensity,
    ArchiveFeedbackSummary? feedbackSummary,
  }) {
    final level =
        intensity ??
        (sharper ? HookRescueIntensity.aggressive : HookRescueIntensity.normal);
    final clock = now ?? DateTime.now();
    final category = pattern.category;
    final template =
        _templates[category] ??
        _templates[FirstSessionPatternCategory.fallback]!;
    final chips = _chipsFor(pattern, template);
    final strength = _strengthFor(pattern);

    // Fallback and lighter stay gentle; we never sharpen them.
    final isEmotional =
        category != FirstSessionPatternCategory.fallback &&
        category != FirstSessionPatternCategory.lighter;

    // Three tiers of question intensity:
    //  - normal   -> category default variant
    //  - elevated -> "sharper" variant copy
    //  - aggressive -> "very sharp" variant copy (most direct)
    final verySharp = level == HookRescueIntensity.aggressive && isEmotional;
    final variants = verySharp
        ? _applyVerySharp(category, template.variants)
        : template.variants;

    // elevated/aggressive default to the sharper variant for emotional
    // categories; everything else keeps the category default.
    final strongActive =
        isEmotional &&
        (level == HookRescueIntensity.elevated ||
            level == HookRescueIntensity.aggressive);
    final selectedVariantId = strongActive
        ? WatchForQuestionVariantId.sharper
        : template.defaultVariantId;

    final prompt = WatchForPrompt(
      id: 'wfp_${clock.microsecondsSinceEpoch}',
      createdAt: clock,
      patternTitle: pattern.title,
      shortPrompt: template.shortPrompt,
      specificPrompt: template.specificPrompt,
      situationHint: template.situationHint,
      emotionalHint: template.emotionalHint,
      checkInQuestion: template.checkInQuestion,
      chips: chips,
      strength: strength,
      questionVariants: variants,
      selectedVariantId: selectedVariantId,
    );

    // Swap when a non-default variant is selected, or when a strong tier needs
    // to replace the live question even if it matches the default id.
    final needsSwap =
        selectedVariantId != template.defaultVariantId || strongActive;
    final base = needsSwap
        ? prompt.withSelectedVariant(selectedVariantId)
        : prompt;
    return _applyFeedbackSummary(base, feedbackSummary);
  }

  /// Gently nudges tomorrow's question when feedback shows a clear pattern.
  /// Never overrides low-confidence prompts or a strong category match.
  WatchForPrompt _applyFeedbackSummary(
    WatchForPrompt prompt,
    ArchiveFeedbackSummary? feedbackSummary,
  ) {
    final issue = feedbackSummary?.dominantIssue;
    if (issue == null || prompt.strength == WatchForPromptStrength.low) {
      return prompt;
    }

    switch (issue) {
      case ArchiveFeedbackType.tooGeneric:
      case ArchiveFeedbackType.moreSpecific:
        return WatchForPrompt(
          id: prompt.id,
          createdAt: prompt.createdAt,
          patternTitle: prompt.patternTitle,
          shortPrompt: prompt.shortPrompt,
          specificPrompt: 'Tomorrow, notice the exact moment this shows up.',
          checkInQuestion: 'What exact moment did this show up?',
          chips: prompt.chips,
          strength: prompt.strength,
          situationHint: prompt.situationHint,
          emotionalHint: prompt.emotionalHint,
          questionVariants: prompt.questionVariants,
          selectedVariantId: prompt.selectedVariantId,
        );
      case ArchiveFeedbackType.alreadyKnew:
        return WatchForPrompt(
          id: prompt.id,
          createdAt: prompt.createdAt,
          patternTitle: prompt.patternTitle,
          shortPrompt: prompt.shortPrompt,
          specificPrompt: 'Tomorrow, notice what changed today.',
          checkInQuestion: 'What changed today?',
          chips: prompt.chips,
          strength: prompt.strength,
          situationHint: prompt.situationHint,
          emotionalHint: prompt.emotionalHint,
          questionVariants: prompt.questionVariants,
          selectedVariantId: prompt.selectedVariantId,
        );
      case ArchiveFeedbackType.notMe:
      case ArchiveFeedbackType.useful:
        return prompt;
    }
  }

  /// Most direct ("very sharp") question per emotional category, used at the
  /// aggressive tier. Kept concrete and emotionally specific, never medical.
  static const Map<FirstSessionPatternCategory, (String, String)>
  _verySharpQuestions = {
    FirstSessionPatternCategory.responsibility: (
      'Did you say yes before checking what you needed?',
      'Tomorrow, notice if you say yes before checking what you need.',
    ),
    FirstSessionPatternCategory.worry: (
      'Did the worry take over when things got quiet?',
      'Tomorrow, notice if the worry takes over when things get quiet.',
    ),
    FirstSessionPatternCategory.relationship: (
      'Did you replay what they said?',
      'Tomorrow, notice if you replay what they said.',
    ),
    FirstSessionPatternCategory.selfDoubt: (
      'Did you act like you had to earn your place?',
      'Tomorrow, notice if you act like you have to earn your place.',
    ),
    FirstSessionPatternCategory.avoidance: (
      'Did you choose relief now and pressure later?',
      'Tomorrow, notice if you choose relief now and pressure later.',
    ),
    FirstSessionPatternCategory.burnout: (
      'Did you ignore tiredness and keep going?',
      'Tomorrow, notice if you ignore tiredness and keep going.',
    ),
  };

  List<WatchForQuestionVariant> _applyVerySharp(
    FirstSessionPatternCategory category,
    List<WatchForQuestionVariant> variants,
  ) {
    final stronger = _verySharpQuestions[category];
    if (stronger == null) return variants;
    return [
      for (final v in variants)
        if (v.id == WatchForQuestionVariantId.sharper)
          WatchForQuestionVariant(
            id: v.id,
            label: v.label,
            question: stronger.$1,
            prompt: stronger.$2,
          )
        else
          v,
    ];
  }

  WatchForItem toWatchForItem(
    WatchForPrompt prompt, {
    required DateTime now,
    String? sourceReflectionId,
  }) {
    return WatchForItem(
      id: 'wf_${now.microsecondsSinceEpoch}',
      createdAt: now,
      targetDate: WatchForItem.dateOnly(now).add(const Duration(days: 1)),
      sourceReflectionId: sourceReflectionId,
      text: prompt.specificPrompt,
      chips: prompt.chips.take(3).toList(),
      status: WatchForStatus.pending,
      result: WatchForResult.none,
      patternTitle: prompt.patternTitle,
      shortPrompt: prompt.shortPrompt,
      specificPrompt: prompt.specificPrompt,
      situationHint: prompt.situationHint,
      emotionalHint: prompt.emotionalHint,
      checkInQuestion: prompt.checkInQuestion,
      promptStrength: prompt.strength.id,
    );
  }

  List<String> _chipsFor(
    FirstSessionPattern pattern,
    _WatchForPromptTemplate template,
  ) {
    if (pattern.chips.isNotEmpty) {
      return pattern.chips.take(3).toList();
    }
    return template.defaultChips.take(3).toList();
  }

  WatchForPromptStrength _strengthFor(FirstSessionPattern pattern) {
    if (pattern.category == FirstSessionPatternCategory.fallback ||
        pattern.isLowConfidence) {
      return WatchForPromptStrength.low;
    }
    if (pattern.confidenceScore >= 0.55 && !pattern.isAmbiguousMatch) {
      return WatchForPromptStrength.high;
    }
    return WatchForPromptStrength.medium;
  }

  static List<WatchForQuestionVariant> _variants({
    required String gentleQuestion,
    required String gentlePrompt,
    required String sharperQuestion,
    required String sharperPrompt,
    required String practicalQuestion,
    required String practicalPrompt,
  }) {
    return [
      WatchForQuestionVariant(
        id: WatchForQuestionVariantId.gentle,
        label: 'Gentle',
        question: gentleQuestion,
        prompt: gentlePrompt,
      ),
      WatchForQuestionVariant(
        id: WatchForQuestionVariantId.sharper,
        label: 'Direct',
        question: sharperQuestion,
        prompt: sharperPrompt,
      ),
      WatchForQuestionVariant(
        id: WatchForQuestionVariantId.practical,
        label: 'Practical',
        question: practicalQuestion,
        prompt: practicalPrompt,
      ),
    ];
  }

  static final Map<FirstSessionPatternCategory, _WatchForPromptTemplate>
  _templates = {
    FirstSessionPatternCategory.responsibility: _WatchForPromptTemplate(
      shortPrompt: 'Notice if you take responsibility before asking for help.',
      specificPrompt:
          'Tomorrow, notice if you say yes or carry something before checking what you need.',
      situationHint: 'especially when someone expects something from you',
      emotionalHint: 'when pressure or guilt shows up first',
      checkInQuestion: 'Did you ask for help, or carry it alone?',
      defaultChips: ['saying yes fast', 'carrying it alone', 'asking late'],
      defaultVariantId: WatchForQuestionVariantId.practical,
      variants: _variants(
        gentleQuestion: 'Did this pattern show up again?',
        gentlePrompt: 'Tomorrow, notice if this pattern shows up again.',
        sharperQuestion: 'Did you carry it alone again?',
        sharperPrompt:
            'Tomorrow, notice if you carry something before asking for help.',
        practicalQuestion: 'Did you ask for help before saying yes?',
        practicalPrompt: 'Tomorrow, notice the moment before you say yes.',
      ),
    ),
    FirstSessionPatternCategory.worry: _WatchForPromptTemplate(
      shortPrompt: 'Notice if the same worry comes back.',
      specificPrompt:
          'Tomorrow, notice if the same worry returns when your mind gets quiet.',
      situationHint: 'especially in the evening or when things slow down',
      emotionalHint: 'when your mind starts looping again',
      checkInQuestion: 'Did it pass, or did it keep looping?',
      defaultChips: ['same worry', 'overthinking', 'hard to switch off'],
      defaultVariantId: WatchForQuestionVariantId.sharper,
      variants: _variants(
        gentleQuestion: 'Did the same worry come back?',
        gentlePrompt: 'Tomorrow, notice if the same worry comes back.',
        sharperQuestion: 'Did the worry keep looping?',
        sharperPrompt: 'Tomorrow, notice if the worry keeps looping.',
        practicalQuestion: 'Did it pass, or did it take over?',
        practicalPrompt: 'Tomorrow, notice whether it passes or takes over.',
      ),
    ),
    FirstSessionPatternCategory.relationship: _WatchForPromptTemplate(
      shortPrompt: 'Notice if this tension stays with you.',
      specificPrompt:
          'Tomorrow, notice if the same person or conversation keeps replaying.',
      situationHint: 'especially after a message or unfinished conversation',
      emotionalHint: 'when someone else stays on your mind',
      checkInQuestion: 'Did it feel resolved, or still heavy?',
      defaultChips: ['same person', 'unsaid tension', 'replaying it'],
      defaultVariantId: WatchForQuestionVariantId.practical,
      variants: _variants(
        gentleQuestion: 'Did the tension stay with you?',
        gentlePrompt: 'Tomorrow, notice if the tension stays with you.',
        sharperQuestion: 'Did that conversation stay with you?',
        sharperPrompt: 'Tomorrow, notice if that conversation stays with you.',
        practicalQuestion: 'Did you clear it up, or carry it?',
        practicalPrompt:
            'Tomorrow, notice whether you clear it up or carry it.',
      ),
    ),
    FirstSessionPatternCategory.selfDoubt: _WatchForPromptTemplate(
      shortPrompt: 'Notice if you feel you need to prove yourself.',
      specificPrompt:
          'Tomorrow, notice if you judge yourself before anything has gone wrong.',
      situationHint: 'especially before you perform or compare yourself',
      emotionalHint: 'when you feel behind or not enough',
      checkInQuestion: 'Did you feel enough, or did you try to prove it?',
      defaultChips: ['not enough', 'proving myself', 'feeling judged'],
      defaultVariantId: WatchForQuestionVariantId.sharper,
      variants: _variants(
        gentleQuestion: 'Did self-doubt show up again?',
        gentlePrompt: 'Tomorrow, notice if self-doubt shows up again.',
        sharperQuestion: 'Did you try to prove yourself again?',
        sharperPrompt: 'Tomorrow, notice if you try to prove yourself again.',
        practicalQuestion: 'Did you judge yourself before anything went wrong?',
        practicalPrompt:
            'Tomorrow, notice if you judge yourself before anything goes wrong.',
      ),
    ),
    FirstSessionPatternCategory.avoidance: _WatchForPromptTemplate(
      shortPrompt: 'Notice if you put off something that matters.',
      specificPrompt:
          'Tomorrow, notice the moment before you delay something you care about.',
      situationHint: 'especially when you know it matters but still pause',
      emotionalHint: 'when starting feels heavier than it should',
      checkInQuestion: 'Did you start, delay, or avoid it?',
      defaultChips: ['putting it off', 'hard to start', 'stuck'],
      defaultVariantId: WatchForQuestionVariantId.practical,
      variants: _variants(
        gentleQuestion: 'Did you delay it again?',
        gentlePrompt: 'Tomorrow, notice if you delay it again.',
        sharperQuestion: 'Did you avoid the moment that mattered?',
        sharperPrompt: 'Tomorrow, notice if you avoid the moment that matters.',
        practicalQuestion: 'Did you start, delay, or avoid it?',
        practicalPrompt:
            'Tomorrow, notice whether you start, delay, or avoid it.',
      ),
    ),
    FirstSessionPatternCategory.burnout: _WatchForPromptTemplate(
      shortPrompt: 'Notice if tiredness changes what you say yes to.',
      specificPrompt:
          'Tomorrow, notice if low energy makes you agree, withdraw, or go quiet.',
      situationHint: 'especially when you are already running on empty',
      emotionalHint: 'when tiredness changes what you agree to',
      checkInQuestion: 'Did you protect your energy, or push through?',
      defaultChips: ['no energy', 'too much', 'feeling heavy'],
      defaultVariantId: WatchForQuestionVariantId.practical,
      variants: _variants(
        gentleQuestion: 'Did tiredness shape your day?',
        gentlePrompt: 'Tomorrow, notice if tiredness shapes your day.',
        sharperQuestion: 'Did you push through when you needed rest?',
        sharperPrompt:
            'Tomorrow, notice if you push through when you need rest.',
        practicalQuestion: 'Did you protect your energy before saying yes?',
        practicalPrompt:
            'Tomorrow, notice if you protect your energy before saying yes.',
      ),
    ),
    FirstSessionPatternCategory.lighter: _WatchForPromptTemplate(
      shortPrompt: 'Notice if this lighter feeling shows up again.',
      specificPrompt:
          'Tomorrow, notice whether this lighter feeling appears in another ordinary moment.',
      situationHint: 'especially in a calm or ordinary part of the day',
      emotionalHint: 'when the day feels a little easier',
      checkInQuestion: 'Was it a one-off, or did it feel lighter again?',
      defaultChips: ['felt lighter', 'calmer moment', 'easier today'],
      defaultVariantId: WatchForQuestionVariantId.gentle,
      variants: _variants(
        gentleQuestion: 'Did this same feeling show up again?',
        gentlePrompt: 'Tomorrow, notice if this same feeling shows up again.',
        sharperQuestion: 'Did it feel heavier, lighter, or different?',
        sharperPrompt:
            'Tomorrow, notice if it feels heavier, lighter, or different.',
        practicalQuestion: 'What changed today?',
        practicalPrompt: 'Tomorrow, notice what changed today.',
      ),
    ),
    FirstSessionPatternCategory.fallback: _WatchForPromptTemplate(
      shortPrompt: 'Notice if this same feeling shows up again.',
      specificPrompt:
          'Tomorrow, notice whether this same feeling appears in another ordinary moment.',
      situationHint: 'especially in an ordinary moment you did not expect',
      emotionalHint: 'when the same feeling returns without a clear reason',
      checkInQuestion: 'Was it a one-off, or did it repeat?',
      defaultChips: ['same feeling', 'same situation', 'same time of day'],
      defaultVariantId: WatchForQuestionVariantId.gentle,
      variants: _variants(
        gentleQuestion: 'Did this same feeling show up again?',
        gentlePrompt: 'Tomorrow, notice if this same feeling shows up again.',
        sharperQuestion: 'Did it feel heavier, lighter, or different?',
        sharperPrompt:
            'Tomorrow, notice if it feels heavier, lighter, or different.',
        practicalQuestion: 'What changed today?',
        practicalPrompt: 'Tomorrow, notice what changed today.',
      ),
    ),
  };
}

class _WatchForPromptTemplate {
  const _WatchForPromptTemplate({
    required this.shortPrompt,
    required this.specificPrompt,
    required this.situationHint,
    required this.emotionalHint,
    required this.checkInQuestion,
    required this.defaultChips,
    required this.variants,
    required this.defaultVariantId,
  });

  final String shortPrompt;
  final String specificPrompt;
  final String situationHint;
  final String emotionalHint;
  final String checkInQuestion;
  final List<String> defaultChips;
  final List<WatchForQuestionVariant> variants;
  final String defaultVariantId;
}