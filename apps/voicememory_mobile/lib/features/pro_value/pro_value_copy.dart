/// Central Pro value copy — proof-first, trail-focused.
abstract final class ProValueCopy {
  ProValueCopy._();

  static const headline =
      'Free shows the first useful proof. Pro keeps the longer trail.';

  static const subheadline =
      'Pro keeps longer evidence history, weekly archive reviews, and timeline views.';

  static const body =
      'ArchiveMe Pro is designed for people who want a longer view of what '
      'keeps repeating, what changed, and what evidence supports it.';

  static const valueBullets = <String>[
    'Longer evidence history',
    'Weekly archive reviews',
    'Timeline views over time',
  ];

  static const cardProLine =
      'Free shows the first useful proof. Pro keeps the longer trail.';

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
  static const accountRestoreNote =
      'Create an account later to restore Pro access when purchases are available.';

  static const primaryCtaLabel = 'Keep building your archive';
  static const secondaryCtaLabel = 'Try Sample Archive';
  static const primaryCtaRoute = '/record';
  static const secondaryCtaRoute = '/sample-archive';

  static const screenTitle = 'ArchiveMe Pro';
  static const settingsTitle = 'ArchiveMe Pro';
  static const settingsSubtitle = headline;

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
    yield accountRestoreNote;
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
