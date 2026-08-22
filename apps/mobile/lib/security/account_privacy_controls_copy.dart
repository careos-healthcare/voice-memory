import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';

/// Account-screen copy for standard archive controls.
abstract class AccountPrivacyControlsCopy {
  AccountPrivacyControlsCopy._();

  static const String sectionTitle = 'Your archive';

  static const String deleteEntry = 'Delete entry';
  static const String correctEntry = 'Correct entry';
  static const String export = 'Export';
  static const String clearArchive = PrivacyClaimCatalogue.clearArchiveAction;
  static const String privacyPolicy = PrivacyClaimCatalogue.privacyPolicyLink;
  static const String support = 'Support';
}