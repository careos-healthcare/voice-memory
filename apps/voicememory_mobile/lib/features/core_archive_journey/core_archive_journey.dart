import 'core_archive_journey_copy.dart';

enum CoreArchiveJourneyStep {
  firstProof,
  whyThisProofAppeared,
  confirmOrCorrect,
  longerEvidenceTrail,
  returnsChangesFadesCorrected,
  proKeepsTheTrail,
}

extension CoreArchiveJourneyStepCopy on CoreArchiveJourneyStep {
  String get copy => switch (this) {
    CoreArchiveJourneyStep.firstProof => CoreArchiveJourneyCopy.firstProof,
    CoreArchiveJourneyStep.whyThisProofAppeared =>
      CoreArchiveJourneyCopy.whyThisProofAppeared,
    CoreArchiveJourneyStep.confirmOrCorrect =>
      CoreArchiveJourneyCopy.confirmOrCorrect,
    CoreArchiveJourneyStep.longerEvidenceTrail =>
      CoreArchiveJourneyCopy.longerEvidenceTrail,
    CoreArchiveJourneyStep.returnsChangesFadesCorrected =>
      CoreArchiveJourneyCopy.returnsChangesFadesCorrected,
    CoreArchiveJourneyStep.proKeepsTheTrail =>
      CoreArchiveJourneyCopy.proKeepsTheTrail,
  };
}

/// Central ArchiveMe product journey — archive over voice assistant.
abstract final class CoreArchiveJourney {
  CoreArchiveJourney._();

  static const steps = CoreArchiveJourneyStep.values;

  static CoreArchiveJourneySnapshot snapshot() =>
      const CoreArchiveJourneySnapshot(
        headline: CoreArchiveJourneyCopy.headline,
        subheadline: CoreArchiveJourneyCopy.subheadline,
        journeyTitle: CoreArchiveJourneyCopy.journeyTitle,
        positioningLine: CoreArchiveJourneyCopy.positioningLine,
        proofOfChangeLine: CoreArchiveJourneyCopy.proofOfChangeLine,
        antiVoiceAssistantGuardrail:
            CoreArchiveJourneyCopy.antiVoiceAssistantGuardrail,
        steps: steps,
        doNotBuildList: CoreArchiveJourneyCopy.doNotBuildList,
      );

  static bool copyPassesPositioningGuard(String text) {
    final lower = text.toLowerCase();
    for (final phrase in CoreArchiveJourneyCopy.bannedPhrases) {
      if (lower.contains(phrase)) return false;
    }
    return true;
  }
}

/// Positioning guardrails that block voice-assistant drift.
abstract final class CoreArchiveJourneyGuardrail {
  CoreArchiveJourneyGuardrail._();

  static bool allowsVoiceAssistantPositioning() => false;

  static bool allowsGenericTranscriptionPositioning() => false;

  static bool allowsRankingDashboardPositioning() => false;

  static bool allowsTherapyDiagnosisPositioning() => false;

  static bool allowsEvidenceTrailPositioning() => true;

  static bool allowsRepeatAndChangePositioning() => true;
}

class CoreArchiveJourneySnapshot {
  const CoreArchiveJourneySnapshot({
    required this.headline,
    required this.subheadline,
    required this.journeyTitle,
    required this.positioningLine,
    required this.proofOfChangeLine,
    required this.antiVoiceAssistantGuardrail,
    required this.steps,
    required this.doNotBuildList,
  });

  final String headline;
  final String subheadline;
  final String journeyTitle;
  final String positioningLine;
  final String proofOfChangeLine;
  final String antiVoiceAssistantGuardrail;
  final List<CoreArchiveJourneyStep> steps;
  final List<String> doNotBuildList;
}
