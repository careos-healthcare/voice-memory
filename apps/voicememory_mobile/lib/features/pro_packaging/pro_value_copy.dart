/// Display-only Pro packaging copy — free vs Pro value split.
abstract final class ProPackagingCopy {
  ProPackagingCopy._();

  static const title = 'ArchiveMe Pro';

  static const subtitle =
      'ArchiveMe is most useful when it can compare moments over time.';

  static const freeSectionTitle = 'Free';
  static const freeBullets = <String>[
    'Start your archive and unlock your first proof.',
  ];

  static const proSectionTitle = 'Pro';
  static const proBullets = <String>[
    'Longer archive history',
    'Private monthly reports',
    'Pattern and change evidence over time',
    'Export/private reports when available',
    'Built around preserving your archive',
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
