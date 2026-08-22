/// When the return-tomorrow cue applies in the early archive loop.
enum ReturnTomorrowCueState {
  afterFirstMoment,
  afterSecondRelated,
  afterFirstProof,
  nextDayReturn,
}

/// Lightweight return guidance — title/body only, no CTAs.
class ReturnTomorrowCue {
  const ReturnTomorrowCue({
    required this.state,
    required this.title,
    required this.body,
    this.watchingPhrase,
  });

  final ReturnTomorrowCueState state;
  final String title;
  final String body;

  /// Grounded phrase included in [body] for next-day return only.
  final String? watchingPhrase;
}