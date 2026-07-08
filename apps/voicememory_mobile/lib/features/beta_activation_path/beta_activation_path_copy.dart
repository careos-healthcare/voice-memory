import 'beta_activation_path_model.dart';

/// Generic beta activation path copy — no private journal text or evidence.
abstract final class BetaActivationPathCopy {
  BetaActivationPathCopy._();

  static const firstSaveTitle = 'Start the beta path';
  static const firstSaveBody =
      'Save one real moment. That gives ArchiveMe something to return to.';
  static const firstSavePrimaryCta = 'Save first moment';
  static const firstSaveSecondaryCta = 'Not now';

  static const secondSaveTitle = 'Come back when something stands out';
  static const secondSaveBody =
      'The second save helps ArchiveMe see whether anything is returning.';
  static const secondSavePrimaryCta = 'Save another moment';
  static const secondSaveSecondaryCta = 'Not today';

  static const thirdSaveTitle = 'One more moment can unlock the first proof';
  static const thirdSaveBody =
      'Three real moments are usually enough for ArchiveMe to start showing the timeline.';
  static const thirdSavePrimaryCta = 'Save one more moment';
  static const thirdSaveSecondaryCta = 'Not today';

  static const proofCheckTitle = 'Check the proof';
  static const proofCheckBody =
      'Look for whether ArchiveMe shows what returned, changed, or faded.';
  static const proofCheckPrimaryCta = 'View timeline proof';
  static const proofCheckSecondaryCta = 'Not now';

  static const valueMomentTitle = 'You reached the value moment';
  static const valueMomentBody =
      'If the proof feels useful, the next question is whether the full timeline is worth keeping.';
  static const valueMomentPrimaryCta = 'See what Pro keeps';
  static const valueMomentSecondaryCta = 'Not now';

  static const proReviewTitle = 'What would make Pro worth it?';
  static const proReviewBody =
      'Use the beta feedback to tell us what is missing before paying.';
  static const proReviewPrimaryCta = 'Review Pro value';
  static const proReviewSecondaryCta = 'Not now';

  static const diagnosisNeedFirstSave = 'Need first save';
  static const diagnosisNeedSecondSave = 'Need second save';
  static const diagnosisNeedThirdSave = 'Need third save';
  static const diagnosisNeedUsefulProof = 'Need useful proof';
  static const diagnosisNeedProPreviewPaywall = 'Need Pro preview/paywall';
  static const diagnosisPaidMomentReached = 'Paid moment reached';

  static const bannedPrivateTerms = <String>[
    'transcript',
    'journal entry',
    'private entry',
    'your words',
  ];

  static const bannedEvidenceTerms = <String>[
    'locked',
    'testimonial',
    'users say',
  ];

  static String diagnosisFor(BetaActivationPathStage stage) => switch (stage) {
        BetaActivationPathStage.firstSave => diagnosisNeedFirstSave,
        BetaActivationPathStage.secondSave => diagnosisNeedSecondSave,
        BetaActivationPathStage.thirdSave => diagnosisNeedThirdSave,
        BetaActivationPathStage.proofCheck => diagnosisNeedUsefulProof,
        BetaActivationPathStage.valueMoment ||
        BetaActivationPathStage.proReview =>
          diagnosisNeedProPreviewPaywall,
        BetaActivationPathStage.paidMomentReached =>
          diagnosisPaidMomentReached,
      };

  static List<String> allVisibleStrings() => [
        firstSaveTitle,
        firstSaveBody,
        firstSavePrimaryCta,
        firstSaveSecondaryCta,
        secondSaveTitle,
        secondSaveBody,
        secondSavePrimaryCta,
        secondSaveSecondaryCta,
        thirdSaveTitle,
        thirdSaveBody,
        thirdSavePrimaryCta,
        thirdSaveSecondaryCta,
        proofCheckTitle,
        proofCheckBody,
        proofCheckPrimaryCta,
        proofCheckSecondaryCta,
        valueMomentTitle,
        valueMomentBody,
        valueMomentPrimaryCta,
        valueMomentSecondaryCta,
        proReviewTitle,
        proReviewBody,
        proReviewPrimaryCta,
        proReviewSecondaryCta,
        diagnosisNeedFirstSave,
        diagnosisNeedSecondSave,
        diagnosisNeedThirdSave,
        diagnosisNeedUsefulProof,
        diagnosisNeedProPreviewPaywall,
        diagnosisPaidMomentReached,
      ];
}
