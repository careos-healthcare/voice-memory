/// Entry-count and dismissal gates for the Pro value preview promo card.
abstract final class ProValuePreviewGates {
  ProValuePreviewGates._();

  static bool showArchivePromo({
    required int entryCount,
    required bool dismissed,
  }) => entryCount >= 3 && !dismissed;
}
