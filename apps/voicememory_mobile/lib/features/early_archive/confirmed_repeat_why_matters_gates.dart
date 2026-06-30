/// Visibility gates for the post-proof "Why this matters" card.
abstract final class ConfirmedRepeatWhyMattersGates {
  ConfirmedRepeatWhyMattersGates._();

  /// Confirmed repeat only — not first 1–2 entry activation cards.
  static const minEntryCount = 3;

  static bool shouldShow({
    required bool loaded,
    required bool viewingConfirmedRepeat,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool dismissed,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      !dismissed &&
      viewingConfirmedRepeat &&
      entryCount >= minEntryCount;
}
