import 'pattern_correction_model.dart';

/// Maps correction reasons to available actions.
abstract final class PatternCorrectionEngine {
  PatternCorrectionEngine._();

  static const reasons = PatternCorrectionReason.values;

  static List<PatternCorrectionAction> actionsFor(
    PatternCorrectionReason reason,
  ) =>
      switch (reason) {
        PatternCorrectionReason.wrongPattern => const [
            PatternCorrectionAction.renamePattern,
            PatternCorrectionAction.removeFromPattern,
            PatternCorrectionAction.betaFeedback,
          ],
        PatternCorrectionReason.wrongWording => const [
            PatternCorrectionAction.renamePattern,
            PatternCorrectionAction.correctTranscript,
          ],
        PatternCorrectionReason.tooPersonal => const [
            PatternCorrectionAction.deleteMoment,
            PatternCorrectionAction.removeFromPattern,
            PatternCorrectionAction.privacyCentre,
          ],
        PatternCorrectionReason.doesNotBelong => const [
            PatternCorrectionAction.removeFromPattern,
            PatternCorrectionAction.deleteMoment,
          ],
        PatternCorrectionReason.notUseful => const [
            PatternCorrectionAction.betaFeedback,
            PatternCorrectionAction.keepRecording,
          ],
      };

  static List<PatternCorrectionAction> availableActions({
    required PatternCorrectionReason reason,
    required PatternCorrectionContext context,
  }) =>
      actionsFor(reason)
          .where((action) => context.allows(action))
          .toList(growable: false);
}
