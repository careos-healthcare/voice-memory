/// Display-only Pro packaging copy — free vs Pro value split.
abstract final class ProPackagingCopy {
  ProPackagingCopy._();

  static const title = 'ArchiveMe Pro';

  static const subtitle =
      'Keep a longer memory of what repeats and how it changes.';

  static const freeSectionTitle = 'Free';
  static const freeBullets = <String>[
    'Start your archive and unlock your first proof.',
  ];

  static const proSectionTitle = 'Pro';
  static const proBullets = <String>[
    'Longer pattern history',
    'Belief change over time',
    'Weekly archive reviews',
    'Private archive reports',
    'Export your archive backup',
  ];

  static const bridgeAfterFirstProof =
      'First proof is free. Pro is for keeping the longer story.';

  static const bridgeAfterBeliefChange =
      'Seeing change over time is the reason to keep your archive.';

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
    yield bridgeAfterFirstProof;
    yield bridgeAfterBeliefChange;
    yield continueCta;
    yield restorePurchases;
    yield offeringsUnavailableBody;
    yield accountTileSubtitle;
  }
}
