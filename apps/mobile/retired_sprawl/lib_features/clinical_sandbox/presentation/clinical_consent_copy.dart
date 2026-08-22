/// Copy for the clinical sandbox consent and SaMD disclaimer flow.
abstract final class ClinicalConsentCopy {
  ClinicalConsentCopy._();

  static const String screenTitle = 'Clinical sandbox consent';

  static const String title = 'Clinical signal research consent';

  static const String samdLead =
      'This experimental sandbox computes passive cognitive biomarkers for '
      'licensed care-team research only. It is not cleared as a medical device.';

  static const String samdLimitationsTitle = 'SaMD limitations acknowledged';

  static const String samdLimitationsBody =
      'I understand this software is not FDA-cleared or CE-marked, does not '
      'diagnose or treat conditions, and must not be used as the sole basis '
      'for clinical decisions.';

  static const String notForDiagnosisTitle = 'Not for diagnosis or emergency use';

  static const String notForDiagnosisBody =
      'I understand ArchiveMe is not therapy, medical advice, or emergency '
      'support, and I will seek licensed care for urgent needs.';

  static const String providerSectionTitle = 'Licensed provider association';

  static const String providerSectionLead =
      'Clinical-signal analysis unlocks only when associated with a verified '
      'licensed provider or care organization.';

  static const String providerNameLabel = 'Provider full name';
  static const String licenseLabel = 'State license number';
  static const String npiLabel = 'NPI or institutional provider ID';
  static const String organizationLabel = 'Care organization';

  static const String submitCta = 'Enable clinical sandbox';
  static const String cancelCta = 'Not now';
  static const String submitting = 'Validating…';

  static const String acknowledgmentsRequired =
      'All required acknowledgments must be checked before continuing.';

  static const String invalidProviderAssociation =
      'Enter a valid licensed provider association.';

  static const String requiredField = 'Required';
}