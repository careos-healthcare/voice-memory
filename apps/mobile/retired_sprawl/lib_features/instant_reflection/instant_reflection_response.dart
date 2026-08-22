/// Conversational archive line shown immediately after save (transcript-backed).
class InstantReflectionResponse {
  const InstantReflectionResponse({
    required this.bodyLine,
    required this.signal,
  });

  final String bodyLine;
  final InstantReflectionSignal signal;
}

enum InstantReflectionSignal {
  uncertainty,
  importance,
  familiarConcern,
  repeatedTopic,
  care,
  listening,
}