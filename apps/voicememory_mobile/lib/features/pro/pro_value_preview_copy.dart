import '../pro_value/pro_value_copy.dart';

/// Static copy for the honest Pro value preview — delegates to [ProValueCopy].
abstract final class ProValuePreviewCopy {
  ProValuePreviewCopy._();

  static const screenTitle = ProValueCopy.screenTitle;
  static const settingsTitle = ProValueCopy.settingsTitle;
  static const settingsSubtitle = ProValueCopy.settingsSubtitle;

  static const archiveCardTitle = ProValueCopy.archiveCardTitle;
  static const archiveCardCta = ProValueCopy.archiveCardCta;
  static const archiveCardDismiss = ProValueCopy.archiveCardDismiss;

  static const headline = ProValueCopy.headline;
  static const subheadline = ProValueCopy.subheadline;
  static const body = ProValueCopy.body;

  static const freeNowTitle = ProValueCopy.freeNowSectionTitle;
  static const freeNowBullets = ProValueCopy.freeNowBullets;

  static const proForTitle = ProValueCopy.proForSectionTitle;
  static const proForBullets = ProValueCopy.valueBullets;

  static const whyTitle = ProValueCopy.whySectionTitle;
  static const whyBodyOne = ProValueCopy.whyBodyOne;
  static const whyBodyTwo = ProValueCopy.whyBodyTwo;

  static const purchaseTitle = ProValueCopy.purchaseSectionTitle;
  static const purchaseUnavailable = ProValueCopy.purchaseUnavailableNote;
  static const purchaseKeepFree = ProValueCopy.purchaseKeepFreeNote;
  static const purchaseAfterSetup = ProValueCopy.purchaseAfterSetupNote;
  static const accountRestoreNote = ProValueCopy.accountRestoreNote;

  static const keepBuildingCta = ProValueCopy.primaryCtaLabel;
  static const trySampleArchiveCta = ProValueCopy.secondaryCtaLabel;

  static Iterable<String> allVisibleCopy() sync* {
    yield* ProValueCopy.allVisibleCopy();
  }
}
