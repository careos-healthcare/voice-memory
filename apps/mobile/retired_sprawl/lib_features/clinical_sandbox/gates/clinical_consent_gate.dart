import 'package:archiveme_mobile/features/clinical_sandbox/stores/clinical_consent_store.dart';

/// Result of evaluating whether clinical-signal analysis may run.
class ClinicalConsentDecision {
  const ClinicalConsentDecision({
    required this.permitted,
    required this.missingAcknowledgments,
    required this.invalidProviderAssociation,
    required this.state,
  });

  const ClinicalConsentDecision.denied({
    required this.missingAcknowledgments,
    required this.invalidProviderAssociation,
    required this.state,
  }) : permitted = false;

  final bool permitted;
  final bool missingAcknowledgments;
  final bool invalidProviderAssociation;
  final ClinicalConsentState state;
}

/// Mandatory gate before any biomarker or trajectory analysis may execute.
class ClinicalConsentGate {
  ClinicalConsentGate(this._store);

  final ClinicalConsentStore _store;

  /// Validates licensed-provider association fields.
  static bool validateProviderAssociation({
    required String providerFullName,
    required String licenseNumber,
    required String npiOrProviderId,
    required String organizationName,
  }) {
    final name = providerFullName.trim();
    final license = licenseNumber.trim();
    final npi = npiOrProviderId.trim();
    final org = organizationName.trim();

    if (name.length < 3) return false;
    if (org.length < 2) return false;
    if (!_licensePattern.hasMatch(license)) return false;
    if (!_npiPattern.hasMatch(npi)) return false;
    return true;
  }

  static final RegExp _licensePattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9\-/.]{3,24}$',
  );

  /// US NPI (10 digits) or institutional provider identifier.
  static final RegExp _npiPattern = RegExp(r'^\d{10}$|^[A-Za-z0-9]{6,16}$');

  Future<ClinicalConsentDecision> evaluate() async {
    final state = await _store.current();
    if (!state.optedIn) {
      return ClinicalConsentDecision.denied(
        missingAcknowledgments: !state.hasRequiredAcknowledgments,
        invalidProviderAssociation: true,
        state: state,
      );
    }

    if (!state.hasRequiredAcknowledgments) {
      return ClinicalConsentDecision.denied(
        missingAcknowledgments: true,
        invalidProviderAssociation: false,
        state: state,
      );
    }

    final providerValid = validateProviderAssociation(
      providerFullName: state.providerFullName,
      licenseNumber: state.providerLicenseNumber,
      npiOrProviderId: state.providerNpiOrId,
      organizationName: state.providerOrganization,
    );

    if (!providerValid) {
      return ClinicalConsentDecision.denied(
        missingAcknowledgments: false,
        invalidProviderAssociation: true,
        state: state,
      );
    }

    return ClinicalConsentDecision(
      permitted: true,
      missingAcknowledgments: false,
      invalidProviderAssociation: false,
      state: state,
    );
  }

  Future<bool> isPermittedNow() async => (await evaluate()).permitted;

  /// Records explicit opt-in after disclaimer acknowledgment and provider validation.
  Future<ClinicalConsentDecision> grant({
    required bool samdLimitationsAcknowledged,
    required bool notForDiagnosisAcknowledged,
    required String providerFullName,
    required String providerLicenseNumber,
    required String providerNpiOrId,
    required String providerOrganization,
    DateTime? consentedAt,
  }) async {
    final providerValid = validateProviderAssociation(
      providerFullName: providerFullName,
      licenseNumber: providerLicenseNumber,
      npiOrProviderId: providerNpiOrId,
      organizationName: providerOrganization,
    );

    if (!samdLimitationsAcknowledged ||
        !notForDiagnosisAcknowledged ||
        !providerValid) {
      return ClinicalConsentDecision.denied(
        missingAcknowledgments:
            !samdLimitationsAcknowledged || !notForDiagnosisAcknowledged,
        invalidProviderAssociation: !providerValid,
        state: const ClinicalConsentState.denied(),
      );
    }

    final next = ClinicalConsentState(
      optedIn: true,
      samdLimitationsAcknowledged: true,
      notForDiagnosisAcknowledged: true,
      providerFullName: providerFullName.trim(),
      providerLicenseNumber: providerLicenseNumber.trim(),
      providerNpiOrId: providerNpiOrId.trim(),
      providerOrganization: providerOrganization.trim(),
      consentedAt: (consentedAt ?? DateTime.now()).toUtc(),
    );
    await _store.save(next);
    return ClinicalConsentDecision(
      permitted: true,
      missingAcknowledgments: false,
      invalidProviderAssociation: false,
      state: next,
    );
  }

  Future<void> revoke() => _store.revoke();
}

/// Thrown when clinical analysis is attempted without active consent.
class ClinicalConsentRequired implements Exception {
  const ClinicalConsentRequired();
  @override
  String toString() => 'ClinicalConsentRequired';
}