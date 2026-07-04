/// Display-only Pro packaging copy — free vs Pro value split.
abstract final class ProPackagingCopy {
  ProPackagingCopy._();

  static const title = 'ArchiveMe Pro';

  static const subtitle =
      'Go deeper into what keeps repeating and what changes.';

  static const freeSectionTitle = 'Start your archive';
  static const freeBullets = <String>[
    'Save moments',
    'Unlock first proof',
    'See your first pattern',
  ];

  static const proSectionTitle = 'Go deeper';
  static const proBullets = <String>[
    'Weekly archive reviews',
    'Change timeline',
    'Private archive report',
    'Longer pattern history',
    'Copy/export your archive summary',
  ];

  static const continueCta = 'Continue';
  static const restorePurchases = 'Restore purchases';

  static const offeringsUnavailableBody =
      'Plans are temporarily unavailable. You can still use ArchiveMe.';

  static const accountTileSubtitle = subtitle;

  static Iterable<String> allVisibleCopy() sync* {
    yield title;
    yield subtitle;
    yield freeSectionTitle;
    yield* freeBullets;
    yield proSectionTitle;
    yield* proBullets;
    yield continueCta;
    yield restorePurchases;
    yield offeringsUnavailableBody;
    yield accountTileSubtitle;
  }
}
