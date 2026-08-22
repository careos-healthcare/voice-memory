import 'package:archiveme_mobile/features/pro_value/pro_value_copy.dart';

/// Static copy for the honest Pro value preview — delegates to [ProValueCopy].
abstract final class ProValuePreviewCopy {
  ProValuePreviewCopy._();

  static const String screenTitle = ProValueCopy.screenTitle;
  static const String settingsTitle = ProValueCopy.settingsTitle;
  static const String settingsSubtitle = ProValueCopy.settingsSubtitle;

  static const String archiveCardTitle = ProValueCopy.archiveCardTitle;
  static const String archiveCardCta = ProValueCopy.archiveCardCta;
  static const String archiveCardDismiss = ProValueCopy.archiveCardDismiss;

  static const String headline = ProValueCopy.headline;
  static const String subheadline = ProValueCopy.subheadline;
  static const String body = ProValueCopy.body;

  static const String freeNowTitle = ProValueCopy.freeNowSectionTitle;
  static const List<String> freeNowBullets = ProValueCopy.freeNowBullets;

  static const String proForTitle = ProValueCopy.proForSectionTitle;
  static const List<String> proForBullets = ProValueCopy.valueBullets;

  static const String whyTitle = ProValueCopy.whySectionTitle;
  static const String whyBodyOne = ProValueCopy.whyBodyOne;
  static const String whyBodyTwo = ProValueCopy.whyBodyTwo;

  static const String purchaseTitle = ProValueCopy.purchaseSectionTitle;
  static const String purchaseUnavailable = ProValueCopy.purchaseUnavailableNote;
  static const String purchaseKeepFree = ProValueCopy.purchaseKeepFreeNote;
  static const String purchaseAfterSetup = ProValueCopy.purchaseAfterSetupNote;
  static const String accountRestoreNote = ProValueCopy.accountRestoreNote;

  static const String keepBuildingCta = ProValueCopy.primaryCtaLabel;
  static const String trySampleArchiveCta = ProValueCopy.secondaryCtaLabel;

  static Iterable<String> allVisibleCopy() sync* {
    yield* ProValueCopy.allVisibleCopy();
  }
}