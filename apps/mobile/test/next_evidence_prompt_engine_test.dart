import 'package:archiveme_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/features/post_save_insight/next_evidence_prompt_engine.dart';
import 'package:archiveme_mobile/features/post_save_insight/post_save_insight_engine.dart';
import 'package:flutter_test/flutter_test.dart';

FirstSessionPattern _pattern() {
  return FirstSessionPattern(
    id: 'test',
    createdAt: DateTime(2026, 6),
    title: 'Taking responsibility before asking for help',
    whyNoticed: 'You mentioned pressure or responsibility.',
    watchForText: 'whether you take responsibility before asking for help',
    chips: const ['saying yes fast'],
    confidenceLabel: FirstSessionConfidenceLabel.early,
    sourceTextPreview: 'I said yes again.',
    matchReason: 'Your words pointed toward pressure in this moment.',
    confidenceScore: 0.5,
    categoryId: 'responsibility',
    category: FirstSessionPatternCategory.responsibility,
  );
}

void main() {
  const promptEngine = NextEvidencePromptEngine();
  const signalEngine = PostSaveInsightEngine();

  test('prompt generated for selected signal', () {
    final signal = signalEngine.build(_pattern()).signals.first;
    final prompts = promptEngine.promptsFor(
      signal: signal,
      pattern: _pattern(),
    );
    expect(prompts, isNotEmpty);
    expect(prompts.first, isNotEmpty);
  });

  test('choose another prompt cycles alternatives', () {
    final signal = signalEngine.build(_pattern()).signals.first;
    final first = promptEngine.promptsFor(
      signal: signal,
      pattern: _pattern(),
    );
    final second = promptEngine.promptsFor(
      signal: signal,
      pattern: _pattern(),
      rotation: 1,
    );
    expect(first.first, isNot(equals(second.first)));
  });
}