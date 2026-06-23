/// Central Pro value copy — deeper long-term evidence history.
abstract final class ProValueCopy {
  ProValueCopy._();

  static const headline = 'Deeper long-term evidence history';

  static const subheadline =
      'See how your archive becomes more useful as evidence grows.';

  static const body =
      'ArchiveMe Pro is designed for people who want a longer view of what '
      'keeps repeating, what changed, and what evidence supports it.';

  static const valueBullets = <String>[
    'Longer archive history',
    'Deeper belief change timeline',
    'More watch themes',
    'Richer weekly and monthly reviews',
    'Advanced export report packs',
    'Deeper context and evidence map views',
  ];

  static const cardProLine =
      'Deeper long-term evidence history is where Pro becomes more useful.';

  static const freeNowSectionTitle = 'What you can use now';
  static const proForSectionTitle = 'What Pro is for';
  static const whySectionTitle = 'Why it matters';
  static const purchaseSectionTitle = 'Purchase status';

  static const freeNowBullets = <String>[
    'Save private moments',
    'Build a cautious archive from your own words',
    'Use Sample Archive to see how comparison works',
    'Export and share proof only when you choose',
  ];

  static const whyBodyOne =
      'The more evidence you save, the more useful your archive becomes.';
  static const whyBodyTwo =
      'Pro is for people who want ArchiveMe to stay useful as a long-term '
      'private evidence archive — not a one-week experiment.';

  static const purchaseUnavailableNote =
      'Purchases are not available yet. The free archive flow remains usable.';
  static const purchaseKeepFreeNote =
      'You can keep using the free archive flow.';
  static const purchaseAfterSetupNote =
      'Pro will be enabled after store setup and sandbox purchase evidence '
      'are complete.';

  static const primaryCtaLabel = 'Keep building your archive';
  static const secondaryCtaLabel = 'Try Sample Archive';
  static const primaryCtaRoute = '/record';
  static const secondaryCtaRoute = '/sample-archive';

  static const screenTitle = 'ArchiveMe Pro';
  static const settingsTitle = 'ArchiveMe Pro';
  static const settingsSubtitle = 'Deeper long-term evidence history';

  static const archiveCardTitle = headline;
  static const archiveCardCta = 'See what Pro is for';
  static const archiveCardDismiss = 'Not now';

  static const proPreviewButton = 'See Pro preview';
  static const proPreviewRoute = '/pro-preview';

  static const helpProLaterTitle = 'Why Pro later?';
  static const helpProLaterNote =
      'Purchases are not available yet. Reviewers can test the free archive '
      'flow and Sample Archive.';

  static Iterable<String> allVisibleCopy() sync* {
    yield headline;
    yield subheadline;
    yield body;
    yield* valueBullets;
    yield cardProLine;
    yield freeNowSectionTitle;
    yield proForSectionTitle;
    yield whySectionTitle;
    yield purchaseSectionTitle;
    yield* freeNowBullets;
    yield whyBodyOne;
    yield whyBodyTwo;
    yield purchaseUnavailableNote;
    yield purchaseKeepFreeNote;
    yield purchaseAfterSetupNote;
    yield primaryCtaLabel;
    yield secondaryCtaLabel;
    yield screenTitle;
    yield settingsTitle;
    yield settingsSubtitle;
    yield archiveCardTitle;
    yield archiveCardCta;
    yield archiveCardDismiss;
    yield proPreviewButton;
    yield helpProLaterTitle;
    yield helpProLaterNote;
  }
}
