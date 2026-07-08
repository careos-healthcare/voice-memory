import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';

import 'first_session_proof_repair_model.dart';

/// First-session + proof quality repair copy — metadata-safe, no journal text.
abstract final class FirstSessionProofRepairCopy {
  FirstSessionProofRepairCopy._();

  // First-session capture repair
  static const captureTitle = 'Save one real moment now';
  static const captureBody =
      'Do not write a journal entry. Save one sentence about something that feels familiar, unfinished, or hard to let go of.';
  static const capturePrimaryCta = 'Type one sentence';
  static const captureSecondaryCta = 'Use voice';
  static const captureMicrocopy =
      'Thirty seconds is enough. ArchiveMe can only show what returns after the first real save.';
  static const typedCapturePrompt = 'One moment that felt familiar was...';

  static const chipKeptCheckingAgain = 'I kept checking again';
  static const chipAvoidedReplying = 'I avoided replying';
  static const chipWantedControl = 'I wanted control';
  static const chipCouldNotLetGo = 'I could not let it go';
  static const chipFeltFamiliar = 'This felt familiar';

  static const captureChipOrder = [
    FirstSessionProofRepairChipId.keptCheckingAgain,
    FirstSessionProofRepairChipId.avoidedReplying,
    FirstSessionProofRepairChipId.wantedControl,
    FirstSessionProofRepairChipId.couldNotLetGo,
    FirstSessionProofRepairChipId.feltFamiliar,
  ];

  static String captureChipText(FirstSessionProofRepairChipId id) =>
      switch (id) {
        FirstSessionProofRepairChipId.keptCheckingAgain =>
          chipKeptCheckingAgain,
        FirstSessionProofRepairChipId.avoidedReplying => chipAvoidedReplying,
        FirstSessionProofRepairChipId.wantedControl => chipWantedControl,
        FirstSessionProofRepairChipId.couldNotLetGo => chipCouldNotLetGo,
        FirstSessionProofRepairChipId.feltFamiliar => chipFeltFamiliar,
      };

  static String captureChipAnalyticsId(FirstSessionProofRepairChipId id) =>
      switch (id) {
        FirstSessionProofRepairChipId.keptCheckingAgain =>
          'kept_checking_again',
        FirstSessionProofRepairChipId.avoidedReplying => 'avoided_replying',
        FirstSessionProofRepairChipId.wantedControl => 'wanted_control',
        FirstSessionProofRepairChipId.couldNotLetGo => 'could_not_let_go',
        FirstSessionProofRepairChipId.feltFamiliar => 'felt_familiar',
      };

  // Proof quality repair
  static const proofTitle = 'Make this proof sharper';
  static const proofBody =
      'ArchiveMe is better when it knows what felt connected. Mark whether this proof was useful, too vague, something you already knew, or not relevant.';
  static const proofCta = 'Answer one tap';

  static const proofNextStepUseful =
      'Good. ArchiveMe will watch whether this gets louder, softer, or fades.';
  static const proofNextStepTooVague =
      'Thanks. ArchiveMe will be more careful and wait for clearer evidence.';
  static const proofNextStepAlreadyKnew =
      'Got it. ArchiveMe will look for what changed, not just what repeated.';
  static const proofNextStepNotRelevant =
      'Thanks. ArchiveMe will reduce this thread and avoid forcing the pattern.';

  static String proofNextStepFor(BetaProofFeedbackType type) => switch (type) {
        BetaProofFeedbackType.useful => proofNextStepUseful,
        BetaProofFeedbackType.tooVague => proofNextStepTooVague,
        BetaProofFeedbackType.alreadyKnew => proofNextStepAlreadyKnew,
        BetaProofFeedbackType.notRelevant => proofNextStepNotRelevant,
      };

  // Dashboard / testing focus
  static const focusUsefulProofQuality = 'Fix useful proof quality';
  static const focusFirstSessionCapture = 'Fix first-session capture';
  static const focusContinueTesting = 'Continue testers';

  static const dashboardFocusSectionTitle = 'Current repair focus';

  static const statusCaptureActive = 'Active at 0 entries';
  static const statusCaptureInactive = 'Inactive';
  static const statusProofActive = 'Active near proof';
  static const statusProofInactive = 'Inactive';

  static Iterable<String> allVisibleStrings() sync* {
    yield captureTitle;
    yield captureBody;
    yield capturePrimaryCta;
    yield captureSecondaryCta;
    yield captureMicrocopy;
    yield typedCapturePrompt;
    yield chipKeptCheckingAgain;
    yield chipAvoidedReplying;
    yield chipWantedControl;
    yield chipCouldNotLetGo;
    yield chipFeltFamiliar;
    yield proofTitle;
    yield proofBody;
    yield proofCta;
    yield proofNextStepUseful;
    yield proofNextStepTooVague;
    yield proofNextStepAlreadyKnew;
    yield proofNextStepNotRelevant;
    yield focusUsefulProofQuality;
    yield focusFirstSessionCapture;
    yield focusContinueTesting;
    for (final type in BetaProofFeedbackType.values) {
      yield proofNextStepFor(type);
    }
  }
}

enum FirstSessionProofRepairActionType {
  typeOneSentence,
  useVoice,
  chipTapped;

  String get analyticsValue => switch (this) {
        FirstSessionProofRepairActionType.typeOneSentence => 'type_one_sentence',
        FirstSessionProofRepairActionType.useVoice => 'use_voice',
        FirstSessionProofRepairActionType.chipTapped => 'chip_tapped',
      };
}
