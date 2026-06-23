/// Static copy for the honest Pro value preview — no purchase pressure.
abstract final class ProValuePreviewCopy {
  ProValuePreviewCopy._();

  static const screenTitle = 'ArchiveMe Pro';

  static const settingsTitle = 'ArchiveMe Pro';
  static const settingsSubtitle = 'See what Pro will unlock.';

  static const archiveCardTitle = 'Pro can make your archive deeper';
  static const archiveCardCta = 'See what Pro unlocks';
  static const archiveCardDismiss = 'Not now';

  static const freeNowTitle = 'What you have now';
  static const freeNowBullets = [
    'Save private moments',
    'See early archive patterns',
    'Use Sample Archive',
    'Export when you choose',
    'Share proof safely',
  ];

  static const proForTitle = 'What Pro is for';
  static const proForBullets = [
    'Deeper belief history over time',
    'Richer weekly reviews',
    'More context evidence views',
    'Better export packs for reflection and review',
    'More advanced archive comparison as your archive grows',
  ];

  static const whyTitle = 'Why it matters';
  static const whyBodyOne =
      'The more evidence you save, the more useful your archive becomes.';
  static const whyBodyTwo =
      'Pro is designed for people who want ArchiveMe to become a long-term private evidence archive.';

  static const purchaseTitle = 'Purchase status';
  static const purchaseUnavailable = 'Purchases are not available yet.';
  static const purchaseKeepFree =
      'You can keep using the free archive flow.';
  static const purchaseAfterSetup =
      'Pro will be enabled after store setup is complete.';

  static const keepBuildingCta = 'Keep building my archive';
  static const trySampleArchiveCta = 'Try Sample Archive';

  static Iterable<String> allVisibleCopy() sync* {
    yield screenTitle;
    yield settingsTitle;
    yield settingsSubtitle;
    yield archiveCardTitle;
    yield archiveCardCta;
    yield archiveCardDismiss;
    yield freeNowTitle;
    yield* freeNowBullets;
    yield proForTitle;
    yield* proForBullets;
    yield whyTitle;
    yield whyBodyOne;
    yield whyBodyTwo;
    yield purchaseTitle;
    yield purchaseUnavailable;
    yield purchaseKeepFree;
    yield purchaseAfterSetup;
    yield keepBuildingCta;
    yield trySampleArchiveCta;
  }
}
