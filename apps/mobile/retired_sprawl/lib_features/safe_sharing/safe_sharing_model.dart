import 'package:archiveme_mobile/features/safe_sharing/safe_sharing_copy.dart';

/// Safe-sharing foundation flags — copy/model only, no product integration.
class SafeSharingFoundation {
  const SafeSharingFoundation({
    required this.sharingLive,
    required this.hasConsentCopy,
    required this.hasFutureLabel,
    required this.hasNoMedicalClaims,
    required this.shareOnlyWhatYouChoose,
    required this.privateReportExplainPattern,
    required this.noDiagnosisDisclaimer,
    required this.userControlIncluded,
    required this.futureSharingPrinciple,
    required this.futureFeatureLabel,
    required this.foundationHeadline,
    required this.foundationBody,
  });

  /// Sharing/send flows are not implemented.
  final bool sharingLive;

  final bool hasConsentCopy;
  final bool hasFutureLabel;
  final bool hasNoMedicalClaims;

  final String shareOnlyWhatYouChoose;
  final String privateReportExplainPattern;
  final String noDiagnosisDisclaimer;
  final String userControlIncluded;
  final String futureSharingPrinciple;
  final String futureFeatureLabel;
  final String foundationHeadline;
  final String foundationBody;

  List<String> get allVisibleStrings => [
    shareOnlyWhatYouChoose,
    privateReportExplainPattern,
    noDiagnosisDisclaimer,
    userControlIncluded,
    futureSharingPrinciple,
    futureFeatureLabel,
    foundationHeadline,
    foundationBody,
  ];

  static SafeSharingFoundation build() {
    final visible = SafeSharingCopy.allVisibleStrings();
    return SafeSharingFoundation(
      sharingLive: false,
      hasConsentCopy: SafeSharingCopy.containsConsentLanguage(visible),
      hasFutureLabel: SafeSharingCopy.labelsFutureFeature(visible),
      hasNoMedicalClaims: SafeSharingCopy.hasNoBannedTerms(visible),
      shareOnlyWhatYouChoose: SafeSharingCopy.shareOnlyWhatYouChoose,
      privateReportExplainPattern: SafeSharingCopy.privateReportExplainPattern,
      noDiagnosisDisclaimer: SafeSharingCopy.noDiagnosisDisclaimer,
      userControlIncluded: SafeSharingCopy.userControlIncluded,
      futureSharingPrinciple: SafeSharingCopy.futureSharingPrinciple,
      futureFeatureLabel: SafeSharingCopy.futureFeatureLabel,
      foundationHeadline: SafeSharingCopy.foundationHeadline,
      foundationBody: SafeSharingCopy.foundationBody,
    );
  }
}