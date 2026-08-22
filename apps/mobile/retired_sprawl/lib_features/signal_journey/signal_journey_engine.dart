import 'package:archiveme_mobile/features/signal_journey/signal_journey_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

/// Status rules and consumer-safe labels for signal journeys.
class SignalJourneyEngine {
  const SignalJourneyEngine();

  static const defaultTargetEvidence = 3;
  static const contradictionThreshold = 2;

  SignalJourneyStatus statusFor({
    required int supportingCount,
    required int contradictionCount,
    required bool archived,
  }) {
    if (archived) return SignalJourneyStatus.archived;
    if (contradictionCount >= contradictionThreshold) {
      return SignalJourneyStatus.contradicted;
    }
    if (supportingCount >= defaultTargetEvidence) {
      return SignalJourneyStatus.confirmedPattern;
    }
    if (supportingCount >= 2) return SignalJourneyStatus.gettingClearer;
    if (supportingCount >= 1) return SignalJourneyStatus.collectingEvidence;
    return SignalJourneyStatus.collectingEvidence;
  }

  String statusLabel(SignalJourneyStatus status) {
    switch (status) {
      case SignalJourneyStatus.collectingEvidence:
        return ConsumerUiCopy.signalJourneyStatusCollecting;
      case SignalJourneyStatus.gettingClearer:
        return ConsumerUiCopy.signalJourneyStatusGettingClearer;
      case SignalJourneyStatus.confirmedPattern:
        return ConsumerUiCopy.signalJourneyStatusConfirmed;
      case SignalJourneyStatus.contradicted:
        return ConsumerUiCopy.signalJourneyStatusContradicted;
      case SignalJourneyStatus.archived:
        return ConsumerUiCopy.signalJourneyStatusArchived;
    }
  }

  String progressLabel(SignalJourney journey) {
    final count = journey.supportingCount.clamp(0, journey.targetEvidenceCount);
    return ConsumerUiCopy.signalJourneyProgress
        .replaceAll('{count}', count.toString())
        .replaceAll('{target}', journey.targetEvidenceCount.toString());
  }

  String watchingLine(SignalJourney journey) {
    return ConsumerUiCopy.signalJourneyWatchingTemplate.replaceAll(
      '{title}',
      journey.signalTitle,
    );
  }

  String recordMoreLine(SignalJourney journey) {
    if (journey.supportingCount >= journey.targetEvidenceCount) {
      return ConsumerUiCopy.signalJourneyRecordMoreComplete;
    }
    return ConsumerUiCopy.signalJourneyRecordMore;
  }

  String completionRepeated(SignalJourney journey) {
    return ConsumerUiCopy.signalJourneyCompletionRepeatedTemplate
        .replaceAll('{title}', journey.signalTitle)
        .replaceAll('{count}', journey.supportingCount.toString());
  }

  String completionChanged(SignalJourney journey) {
    if (journey.contradictingMomentIds.isEmpty) {
      return ConsumerUiCopy.signalJourneyCompletionChangedNone;
    }
    return ConsumerUiCopy.signalJourneyCompletionChangedSome;
  }

  String completionWatchNext(SignalJourney journey) {
    if (journey.nextPrompt.trim().isNotEmpty) return journey.nextPrompt;
    return ConsumerUiCopy.signalJourneyCompletionWatchDefault;
  }

  bool matchesSignal(
    SignalJourney journey, {
    required String signalId,
    String? readId,
    String? categoryId,
    String? signalTitle,
  }) {
    if (journey.signalId == signalId) return true;
    if (readId != null && journey.readId != null && journey.readId == readId) {
      return true;
    }
    if (categoryId != null &&
        journey.categoryId == categoryId &&
        signalTitle != null &&
        journey.signalTitle == signalTitle) {
      return true;
    }
    return false;
  }
}