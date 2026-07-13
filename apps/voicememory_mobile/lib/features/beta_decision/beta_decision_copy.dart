import 'beta_decision_model.dart';

/// Internal beta decision copy — plain language for founders/operators only.
abstract final class BetaDecisionCopy {
  BetaDecisionCopy._();

  static const cardTitle = 'Beta next-build decision';
  static const cardSubtitle =
      'Log tester outcomes from docs/BETA_DECISION_SYSTEM.md. '
      'Build only the highest-priority failing branch.';

  static const holdDoNotExpand = 'Do not build expansion yet.';
  static const nextFixRecordOnboarding = 'Next build: fix Record/onboarding copy.';
  static const nextFixCaptureFriction = 'Next build: reduce capture friction.';
  static const nextAddReturnReason = 'Next build: add return reason.';
  static const nextImproveProofClarity =
      'Next build: improve proof emotional clarity.';
  static const nextSharpenProPackaging = 'Next build: sharpen Pro packaging.';
  static const nextExpandProUtility = 'Next build: expand Pro utility.';

  static const insufficientDataBody =
      'No tester outcomes logged yet. Run the 5-person script before choosing a build branch.';

  static const noFailingBranchBody =
      'No failing branch detected in logged outcomes. Continue observation or run more testers.';

  static String recommendationFor(BetaNextBuildRecommendation recommendation) =>
      switch (recommendation) {
        BetaNextBuildRecommendation.fixRecordOnboardingCopy =>
          nextFixRecordOnboarding,
        BetaNextBuildRecommendation.fixCaptureFriction => nextFixCaptureFriction,
        BetaNextBuildRecommendation.addReturnReason => nextAddReturnReason,
        BetaNextBuildRecommendation.improveProofEmotionalClarity =>
          nextImproveProofClarity,
        BetaNextBuildRecommendation.sharpenProPackaging =>
          nextSharpenProPackaging,
        BetaNextBuildRecommendation.expandProUtility => nextExpandProUtility,
        BetaNextBuildRecommendation.holdDoNotExpand => holdDoNotExpand,
        BetaNextBuildRecommendation.insufficientData => insufficientDataBody,
        BetaNextBuildRecommendation.noFailingBranch => noFailingBranchBody,
      };

  static const decisionTreeBranches = <String>[
    'A. Misunderstanding → fix Record/onboarding copy only',
    'B. Understands but does not record → fix capture friction',
    'C. Records once but does not return → add return reason / three-day proof challenge',
    'D. Reaches proof but does not care → improve proof emotional clarity',
    'E. Cares but will not pay → sharpen Pro packaging',
    'F. Asks for history/export/report after caring → expand Pro utility',
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield cardTitle;
    yield cardSubtitle;
    yield holdDoNotExpand;
    yield nextFixRecordOnboarding;
    yield nextFixCaptureFriction;
    yield nextAddReturnReason;
    yield nextImproveProofClarity;
    yield nextSharpenProPackaging;
    yield nextExpandProUtility;
    yield insufficientDataBody;
    yield noFailingBranchBody;
    yield* decisionTreeBranches;
    yield* BetaTesterOutcomeChecklist.interviewQuestions;
  }
}
