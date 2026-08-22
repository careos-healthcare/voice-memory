import 'package:archiveme_mobile/core/user/life_stage_lens.dart';

/// Dedicated configuration for the Career Transition thematic lens.
abstract final class CareerTransitionLens {
  CareerTransitionLens._();

  static const lensId = 'careerTransition';

  /// Wire value aligned with [LifeStageLens.careerTransition].
  static const String wireValue = lensId;

  /// Active listening targets — mirrored from shared TS config.
  static const listenTargets = [
    'professional identity shifts (title, team, industry, founder vs employee)',
    'skill-transfer beliefs (what transfers, what feels obsolete, imposter vs mastery)',
    'risk-tolerance contradictions (stated safety vs leap language in the same week)',
    'changing definitions of success (money, impact, autonomy, prestige, time)',
  ];

  /// System prompt injection for fact_ledger evaluation (API + local mirror).
  static const systemPromptInjection = '''
CAREER TRANSITION LENS — listen actively for:
1. professional identity shifts (title, team, industry, founder vs employee)
2. skill-transfer beliefs (what transfers, what feels obsolete, imposter vs mastery)
3. risk-tolerance contradictions (stated safety vs leap language in the same week)
4. changing definitions of success (money, impact, autonomy, prestige, time)
Quote job titles, company or team names, project codenames, and calendar dates from entries.
Prefer contradiction and beliefChange kinds when risk talk conflicts with action.
Never output generic career-coaching platitudes without citing a specific workplace situation from the ledger.''';

  /// Primary cold-start onboarding question — seeds transition-specific evidence.
  static const primaryColdStartPrompt =
      'What was the tipping point that made you decide to make this change?';

  /// Rotating cold-start prompts for brain-dump onboarding capture.
  static const List<String> coldStartPromptSeeds = [
    primaryColdStartPrompt,
    'What part of your old role do you refuse to carry forward?',
    'What skill from your last job do you believe transfers — and what feels obsolete?',
    'When did your definition of success last change, and what triggered it?',
    'What risk are you taking now that you would not have taken a year ago?',
    'Who at work changed how you see this transition?',
  ];

  static const coldStartTitle = 'Capture your career transition';
  static const coldStartSubtitle =
      'Start with the tipping point — names, teams, and dates help ArchiveMe '
      'build your fact ledger.';

  static bool get isCareerTransitionLens => true;

  static bool matches(LifeStageLens? lens) =>
      lens == LifeStageLens.careerTransition;
}