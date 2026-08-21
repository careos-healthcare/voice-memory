class PredictionEvent {
  const PredictionEvent({
    required this.triggerEntryId,
    required this.outcomeEntryId,
    required this.triggerQuote,
    required this.outcomeQuote,
    required this.recordedAt,
  });

  final String triggerEntryId;
  final String outcomeEntryId;
  final String triggerQuote;
  final String outcomeQuote;
  final DateTime recordedAt;
}

class PredictionInsight {
  const PredictionInsight({
    required this.id,
    required this.title,
    required this.summary,
    required this.confidence,
    required this.evidenceCount,
    required this.supportingEvents,
    required this.outcomeDescription,
  });

  final String id;
  final String title;
  final String summary;
  final int confidence;
  final int evidenceCount;
  final List<PredictionEvent> supportingEvents;
  final String outcomeDescription;
}