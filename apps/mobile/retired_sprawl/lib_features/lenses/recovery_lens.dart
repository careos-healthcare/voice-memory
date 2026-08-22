import 'package:archiveme_mobile/core/user/life_stage_lens.dart';

/// Recovery / sobriety lens — neutral mirror only; strict correction trust.
abstract final class RecoveryLens {
  RecoveryLens._();

  static const lensId = 'recovery';
  static const String wireValue = lensId;

  /// Applied to negative correction history counts when this lens is active.
  static const suppressionHistoryMultiplier = 3;

  static const listenTargets = [
    'behavior sequences the user describes (where, when, with whom — cite entry dates)',
    'triggers and cue language in their own words (places, people, times, emotions)',
    'rationalizations and reversals ("just this once", "I can handle it", later regret)',
    'setback-and-return cycles without labeling them clinically',
  ];

  static const forbiddenOutput = [
    'clinical advice, diagnoses, or disorder labels',
    'therapeutic directives ("you should", "try", "consider seeking")',
    'motivational coaching or reassurance not grounded in cited ledger entries',
    'treatment plans, step-work instructions, or sobriety prescriptions',
  ];

  static const systemPromptInjection = '''
RECOVERY / SOBRIETY LENS — neutral mirror only:
1. behavior sequences the user describes (where, when, with whom — cite entry dates)
2. triggers and cue language in their own words (places, people, times, emotions)
3. rationalizations and reversals ("just this once", "I can handle it", later regret)
4. setback-and-return cycles without labeling them clinically
STRICT PROHIBITIONS:
- clinical advice, diagnoses, or disorder labels
- therapeutic directives ("you should", "try", "consider seeking")
- motivational coaching or reassurance not grounded in cited ledger entries
- treatment plans, step-work instructions, or sobriety prescriptions
Reflect only what appears in fact_ledger entries — quote dates, places, and the user's phrasing.
Prefer contradiction kind when stated intent conflicts with described behavior in the same week.
If evidence is thin, say so plainly; never fill gaps with clinical or coaching language.''';

  static const coldStartPromptSeeds = [
    'What happened right before the urge or behavior you are tracking?',
    'Where were you, and who was around, the last time this pattern showed up?',
    'What story did you tell yourself in the moment — and what changed afterward?',
    'What trigger keeps returning even when you say you are done with it?',
  ];

  static const coldStartTitle = 'Capture what happened';
  static const coldStartSubtitle =
      'Neutral mirror only — describe triggers, places, and what you told yourself. '
      'No advice, just your words for the fact ledger.';

  static bool matches(LifeStageLens? lens) => lens == LifeStageLens.recovery;

  static int scaleSuppressionCount(int count) =>
      count <= 0 ? 0 : count * suppressionHistoryMultiplier;
}