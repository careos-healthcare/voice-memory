/// Canonical purchase-confidence copy — privacy and control reassurance only.
abstract final class PurchaseConfidenceCopy {
  PurchaseConfidenceCopy._();

  static const coreMessage =
      'Your archive stays private. Pro keeps the timeline; it does not change who controls your entries.';

  static const cardTitle = 'Private by default';

  static const body =
      'Your saved moments stay yours. You can delete entries, correct ArchiveMe, and restore purchases if needed.';

  static const trustBullets = <String>[
    'You control what you save',
    'You can delete entries',
    'You can correct the timeline',
    'Restore purchases is available',
    'Pro keeps the timeline as it grows',
  ];

  static const footer =
      'Pro does not make medical, therapy, or diagnostic claims.';

  /// Compact bridge line for Pro upsell surfaces — not the full card.
  static const compactTrustLine = coreMessage;

  static List<String> allCardStrings() => [
    cardTitle,
    body,
    ...trustBullets,
    footer,
  ];
}
