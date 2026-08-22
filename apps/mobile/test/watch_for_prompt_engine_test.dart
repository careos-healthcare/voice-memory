import 'package:archiveme_mobile/features/feedback/archive_feedback_model.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_summary_engine.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_prompt_engine.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_prompt_model.dart';
import 'package:archiveme_mobile/features/trial/hook_rescue_decision_model.dart';
import 'package:flutter_test/flutter_test.dart';

FirstSessionPattern _pattern({
  required String categoryId,
  required String title,
  double confidence = 0.6,
  List<String> chips = const [],
}) {
  return FirstSessionPattern(
    id: 'p1',
    createdAt: DateTime(2026, 5, 25),
    title: title,
    whyNoticed: 'why',
    watchForText: 'whether something shows up again',
    chips: chips,
    confidenceLabel: FirstSessionConfidenceLabel.early,
    sourceTextPreview: 'preview',
    matchReason: 'reason',
    confidenceScore: confidence,
    categoryId: categoryId,
  );
}

void main() {
  const engine = WatchForPromptEngine();

  test('responsibility prompt includes help and say yes language', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'responsibility',
        title: 'Taking responsibility before asking for help',
      ),
    );
    expect(prompt.shortPrompt, contains('responsibility'));
    expect(prompt.shortPrompt, contains('help'));
    expect(prompt.specificPrompt, contains('say yes'));
    expect(prompt.specificPrompt, contains('carry'));
    expect(prompt.checkInQuestion, contains('help'));
  });

  test('worry prompt includes same worry and looping language', () {
    final prompt = engine.build(
      pattern: _pattern(categoryId: 'worry', title: 'The same worry returning'),
    );
    expect(prompt.shortPrompt, contains('same worry'));
    expect(prompt.specificPrompt, contains('same worry'));
    expect(prompt.checkInQuestion, contains('looping'));
  });

  test('relationship prompt includes tension and replaying', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'relationship',
        title: 'Carrying tension with someone',
      ),
    );
    expect(prompt.shortPrompt, contains('tension'));
    expect(prompt.specificPrompt, contains('replaying'));
  });

  test('selfDoubt prompt includes prove yourself', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'selfDoubt',
        title: 'Trying to prove you are enough',
      ),
    );
    expect(prompt.shortPrompt, contains('prove yourself'));
    expect(prompt.checkInQuestion, contains('enough'));
  });

  test('avoidance prompt includes put off and delay', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'avoidance',
        title: 'Putting off what matters',
      ),
    );
    expect(prompt.shortPrompt, contains('put off'));
    expect(prompt.checkInQuestion, contains('delay'));
  });

  test('burnout prompt includes tiredness and energy', () {
    final prompt = engine.build(
      pattern: _pattern(categoryId: 'burnout', title: 'Running on empty'),
    );
    expect(prompt.shortPrompt, contains('tiredness'));
    expect(prompt.specificPrompt, contains('energy'));
  });

  test('fallback produces soft repeatable prompt', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'fallback',
        title: 'Something worth watching',
        confidence: 0.2,
      ),
    );
    expect(prompt.shortPrompt, contains('same feeling'));
    expect(prompt.specificPrompt, contains('ordinary moment'));
    expect(prompt.strength, WatchForPromptStrength.low);
  });

  test('toWatchForItem stores specific prompt as pending text', () {
    final prompt = engine.build(
      pattern: _pattern(categoryId: 'worry', title: 'The same worry returning'),
    );
    final item = engine.toWatchForItem(prompt, now: DateTime(2026, 5, 25, 10));
    expect(item.text, prompt.specificPrompt);
    expect(item.checkInQuestion, prompt.checkInQuestion);
    expect(item.hasRichPrompt, isTrue);
  });

  test('maps lighter category to lighter template', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'lighter',
        title: 'Something felt lighter today',
      ),
    );
    expect(prompt.shortPrompt, contains('lighter'));
    expect(prompt.specificPrompt, contains('lighter'));
  });

  test('every category exposes at least 3 question variants', () {
    for (final category in FirstSessionPatternCategory.values) {
      final prompt = engine.build(
        pattern: _pattern(categoryId: category.id, title: 'Pattern'),
      );
      expect(
        prompt.questionVariants.length,
        greaterThanOrEqualTo(3),
        reason: 'category ${category.id} should expose 3 variants',
      );
      final ids = prompt.questionVariants.map((v) => v.id).toSet();
      expect(ids, containsAll(['gentle', 'sharper', 'practical']));
      expect(prompt.selectedVariantId, isNotNull);
    }
  });

  WatchForQuestionVariant variantOf(WatchForPrompt prompt, String id) =>
      prompt.questionVariants.firstWhere((v) => v.id == id);

  test('responsibility sharper variant asks about carrying it alone', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'responsibility',
        title: 'Taking responsibility before asking for help',
      ),
    );
    expect(
      variantOf(prompt, 'sharper').question,
      'Did you carry it alone again?',
    );
    expect(
      variantOf(prompt, 'practical').question,
      'Did you ask for help before saying yes?',
    );
    expect(prompt.selectedVariantId, 'practical');
  });

  test('worry sharper variant mentions looping', () {
    final prompt = engine.build(
      pattern: _pattern(categoryId: 'worry', title: 'The same worry returning'),
    );
    expect(variantOf(prompt, 'sharper').question, contains('looping'));
    expect(prompt.selectedVariantId, 'sharper');
  });

  test('fallback exposes gentle and practical variants', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'fallback',
        title: 'Something worth watching',
        confidence: 0.2,
      ),
    );
    expect(variantOf(prompt, 'gentle').question, contains('show up again'));
    expect(variantOf(prompt, 'practical').question, contains('changed'));
    expect(prompt.selectedVariantId, 'gentle');
  });

  test('legacy sharper flag maps to the very-sharp tier', () {
    final prompt = engine.build(
      pattern: _pattern(categoryId: 'worry', title: 'The same worry returning'),
      sharper: true,
    );
    expect(prompt.selectedVariantId, 'sharper');
    expect(
      variantOf(prompt, 'sharper').question,
      'Did the worry take over when things got quiet?',
    );
    // Selected variant is applied to the live question.
    expect(
      prompt.checkInQuestion,
      'Did the worry take over when things got quiet?',
    );
  });

  test('elevated tier uses sharper question per category', () {
    final expected = <String, String>{
      'responsibility': 'Did you carry it alone again?',
      'worry': 'Did the worry keep looping?',
      'relationship': 'Did that conversation stay with you?',
      'selfDoubt': 'Did you try to prove yourself again?',
      'avoidance': 'Did you avoid the moment that mattered?',
      'burnout': 'Did you push through when you needed rest?',
    };
    expected.forEach((categoryId, question) {
      final prompt = engine.build(
        pattern: _pattern(categoryId: categoryId, title: 'Pattern'),
        intensity: HookRescueIntensity.elevated,
      );
      expect(
        variantOf(prompt, 'sharper').question,
        question,
        reason: 'sharper question for $categoryId',
      );
      expect(prompt.selectedVariantId, 'sharper');
      expect(prompt.checkInQuestion, question);
    });
  });

  test('aggressive tier uses very-sharp question per category', () {
    final expected = <String, String>{
      'responsibility': 'Did you say yes before checking what you needed?',
      'worry': 'Did the worry take over when things got quiet?',
      'relationship': 'Did you replay what they said?',
      'selfDoubt': 'Did you act like you had to earn your place?',
      'avoidance': 'Did you choose relief now and pressure later?',
      'burnout': 'Did you ignore tiredness and keep going?',
    };
    expected.forEach((categoryId, question) {
      final prompt = engine.build(
        pattern: _pattern(categoryId: categoryId, title: 'Pattern'),
        intensity: HookRescueIntensity.aggressive,
      );
      expect(
        variantOf(prompt, 'sharper').question,
        question,
        reason: 'very-sharp question for $categoryId',
      );
      expect(prompt.selectedVariantId, 'sharper');
      expect(prompt.checkInQuestion, question);
    });
  });

  test('responsibility very-sharp matches expected copy', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'responsibility',
        title: 'Taking responsibility before asking for help',
      ),
      intensity: HookRescueIntensity.aggressive,
    );
    expect(
      prompt.checkInQuestion,
      'Did you say yes before checking what you needed?',
    );
  });

  test('worry very-sharp matches expected copy', () {
    final prompt = engine.build(
      pattern: _pattern(categoryId: 'worry', title: 'The same worry returning'),
      intensity: HookRescueIntensity.aggressive,
    );
    expect(
      prompt.checkInQuestion,
      'Did the worry take over when things got quiet?',
    );
  });

  test('fallback and lighter stay gentle even when aggressive', () {
    for (final categoryId in ['fallback', 'lighter']) {
      final prompt = engine.build(
        pattern: _pattern(
          categoryId: categoryId,
          title: 'Something worth watching',
          confidence: 0.2,
        ),
        intensity: HookRescueIntensity.aggressive,
      );
      expect(
        prompt.selectedVariantId,
        isNot('sharper'),
        reason: '$categoryId should not be sharpened',
      );
    }
  });

  test('non-sharper build keeps category default variant', () {
    final prompt = engine.build(
      pattern: _pattern(categoryId: 'worry', title: 'The same worry returning'),
    );
    expect(prompt.selectedVariantId, 'sharper');
    expect(variantOf(prompt, 'sharper').question, contains('looping'));
  });

  test('elevated intensity defaults emotional category to sharper', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'responsibility',
        title: 'Taking responsibility before asking for help',
      ),
      intensity: HookRescueIntensity.elevated,
    );
    expect(prompt.selectedVariantId, 'sharper');
    // elevated keeps the standard (non-very-sharp) sharper wording.
    expect(
      variantOf(prompt, 'sharper').question,
      'Did you carry it alone again?',
    );
  });

  test('elevated intensity keeps fallback default variant', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'fallback',
        title: 'Something worth watching',
        confidence: 0.2,
      ),
      intensity: HookRescueIntensity.elevated,
    );
    expect(prompt.selectedVariantId, 'gentle');
  });

  test('elevated intensity keeps lighter default variant', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'lighter',
        title: 'Something felt lighter today',
      ),
      intensity: HookRescueIntensity.elevated,
    );
    expect(prompt.selectedVariantId, isNot('sharper'));
  });

  test('aggressive intensity uses very-sharp question and selects sharper', () {
    final prompt = engine.build(
      pattern: _pattern(categoryId: 'worry', title: 'The same worry returning'),
      intensity: HookRescueIntensity.aggressive,
    );
    expect(prompt.selectedVariantId, 'sharper');
    expect(
      variantOf(prompt, 'sharper').question,
      'Did the worry take over when things got quiet?',
    );
    expect(
      prompt.checkInQuestion,
      'Did the worry take over when things got quiet?',
    );
  });

  test('withSelectedVariant swaps question and prompt', () {
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'responsibility',
        title: 'Taking responsibility before asking for help',
      ),
    );
    final sharper = prompt.withSelectedVariant('sharper');
    expect(sharper.checkInQuestion, 'Did you carry it alone again?');
    expect(
      sharper.specificPrompt,
      'Tomorrow, notice if you carry something before asking for help.',
    );
    expect(sharper.selectedVariantId, 'sharper');
  });

  test('tooGeneric feedback summary prefers an exact-moment question', () {
    const engine = WatchForPromptEngine();
    const summary = ArchiveFeedbackSummary(
      total: 2,
      usefulCount: 0,
      tooGenericCount: 2,
      notMeCount: 0,
      alreadyKnewCount: 0,
      moreSpecificCount: 0,
      dominantIssue: ArchiveFeedbackType.tooGeneric,
    );
    final prompt = engine.build(
      pattern: _pattern(
        categoryId: 'responsibility',
        title: 'Taking responsibility before asking for help',
      ),
      feedbackSummary: summary,
    );
    expect(prompt.checkInQuestion, 'What exact moment did this show up?');
  });

  test('alreadyKnew feedback summary emphasizes what changed', () {
    const engine = WatchForPromptEngine();
    const summary = ArchiveFeedbackSummary(
      total: 2,
      usefulCount: 0,
      tooGenericCount: 0,
      notMeCount: 0,
      alreadyKnewCount: 2,
      moreSpecificCount: 0,
      dominantIssue: ArchiveFeedbackType.alreadyKnew,
    );
    final prompt = engine.build(
      pattern: _pattern(categoryId: 'worry', title: 'The same worry returning'),
      feedbackSummary: summary,
    );
    expect(prompt.checkInQuestion, 'What changed today?');
  });
}