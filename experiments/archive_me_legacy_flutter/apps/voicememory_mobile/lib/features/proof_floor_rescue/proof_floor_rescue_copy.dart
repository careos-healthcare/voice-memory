import '../beta_proof_feedback/beta_proof_feedback_model.dart';

/// Proof floor rescue copy — cautious proof states, metadata-safe.
abstract final class ProofFloorRescueCopy {
  ProofFloorRescueCopy._();

  static const waitTitle = 'ArchiveMe is still watching this';
  static const waitBody =
      'There is not enough clear evidence yet to call this a pattern. Save one more moment if it comes back.';
  static const waitPrimaryCta = 'Save if it returns';
  static const waitSecondaryCta = 'Not now';

  static const feedbackTitle = 'Was this proof actually useful?';
  static const feedbackBody =
      'One tap helps ArchiveMe avoid forcing patterns that do not feel real.';

  static const sharpenTitle = 'Make the next proof sharper';
  static const sharpenBody =
      'Next time, save what changed: did it feel louder, softer, easier, or exactly the same?';
  static const sharpenPrimaryCta = 'Save the next return';
  static const sharpenSecondaryCta = 'Not today';

  static const suppressTitle = 'ArchiveMe will back off this thread';
  static const suppressBody =
      'This pattern will be treated as weaker unless clearer evidence returns.';
  static const suppressPrimaryCta = 'Continue';

  static const dashboardFocusTitle = 'Protect proof floor';
  static const dashboardFocusBody =
      'Useful proof is below the safe floor. Make weak proof more cautious before pushing Pro.';
  static const dashboardFocusLabel = dashboardFocusTitle;

  static const statusProBlocked = 'Pro blocked by weak proof';
  static const statusProAllowed = 'Pro path allowed';
  static const statusProofSafe = 'Proof safe enough to monetize';
  static const statusProofNotSafe = 'Proof not safe to monetize';

  static String stateLabel(ProofFloorRescueState state) => switch (state) {
    ProofFloorRescueState.waitForClearerEvidence => 'waitForClearerEvidence',
    ProofFloorRescueState.needsSpecificFeedback => 'needsSpecificFeedback',
    ProofFloorRescueState.sharpenNextReturn => 'sharpenNextReturn',
    ProofFloorRescueState.suppressThread => 'suppressThread',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield waitTitle;
    yield waitBody;
    yield waitPrimaryCta;
    yield waitSecondaryCta;
    yield feedbackTitle;
    yield feedbackBody;
    yield sharpenTitle;
    yield sharpenBody;
    yield sharpenPrimaryCta;
    yield sharpenSecondaryCta;
    yield suppressTitle;
    yield suppressBody;
    yield suppressPrimaryCta;
    yield dashboardFocusTitle;
    yield dashboardFocusBody;
    yield dashboardFocusLabel;
    yield statusProBlocked;
    yield statusProAllowed;
    yield statusProofSafe;
    yield statusProofNotSafe;
    for (final type in BetaProofFeedbackType.values) {
      yield type.diagnosticsLabel;
    }
  }
}

enum ProofFloorRescueState {
  waitForClearerEvidence,
  needsSpecificFeedback,
  sharpenNextReturn,
  suppressThread,
}

extension ProofFloorRescueStateAnalytics on ProofFloorRescueState {
  String get analyticsValue => ProofFloorRescueCopy.stateLabel(this);
}

enum ProofFloorRescueCtaType {
  saveIfReturns,
  notNow,
  saveNextReturn,
  skip,
  continueThread;

  String get analyticsValue => switch (this) {
    ProofFloorRescueCtaType.saveIfReturns => 'save_if_returns',
    ProofFloorRescueCtaType.notNow => 'not_now',
    ProofFloorRescueCtaType.saveNextReturn => 'save_next_return',
    ProofFloorRescueCtaType.skip => 'skip',
    ProofFloorRescueCtaType.continueThread => 'continue',
  };
}

enum ProofFloorRescueRepairFocusId { protectProofFloor }
