/// Visibility gates for Then vs Now surfaces.
abstract final class ThenNowGates {
  ThenNowGates._();

  static bool showOnArchiveHome({
    required bool hasCard,
    required bool sampleMode,
  }) => hasCard && !sampleMode;
}