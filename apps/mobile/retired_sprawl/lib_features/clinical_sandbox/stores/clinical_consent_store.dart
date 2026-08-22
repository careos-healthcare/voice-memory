import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persisted clinical sandbox consent — device-local encrypted prefs partition.
class ClinicalConsentState {
  const ClinicalConsentState({
    required this.optedIn,
    required this.samdLimitationsAcknowledged,
    required this.notForDiagnosisAcknowledged,
    required this.providerFullName,
    required this.providerLicenseNumber,
    required this.providerNpiOrId,
    required this.providerOrganization,
    this.consentedAt,
  });

  const ClinicalConsentState.denied()
    : optedIn = false,
      samdLimitationsAcknowledged = false,
      notForDiagnosisAcknowledged = false,
      providerFullName = '',
      providerLicenseNumber = '',
      providerNpiOrId = '',
      providerOrganization = '',
      consentedAt = null;

  final bool optedIn;
  final bool samdLimitationsAcknowledged;
  final bool notForDiagnosisAcknowledged;
  final String providerFullName;
  final String providerLicenseNumber;
  final String providerNpiOrId;
  final String providerOrganization;
  final DateTime? consentedAt;

  bool get hasRequiredAcknowledgments =>
      samdLimitationsAcknowledged && notForDiagnosisAcknowledged;

  Map<String, dynamic> toJson() => {
    'optedIn': optedIn,
    'samdLimitationsAcknowledged': samdLimitationsAcknowledged,
    'notForDiagnosisAcknowledged': notForDiagnosisAcknowledged,
    'providerFullName': providerFullName,
    'providerLicenseNumber': providerLicenseNumber,
    'providerNpiOrId': providerNpiOrId,
    'providerOrganization': providerOrganization,
    'consentedAt': consentedAt?.toUtc().toIso8601String(),
  };

  static ClinicalConsentState fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const ClinicalConsentState.denied();
    }
    return ClinicalConsentState(
      optedIn: json['optedIn'] == true,
      samdLimitationsAcknowledged: json['samdLimitationsAcknowledged'] == true,
      notForDiagnosisAcknowledged: json['notForDiagnosisAcknowledged'] == true,
      providerFullName: json['providerFullName'] as String? ?? '',
      providerLicenseNumber: json['providerLicenseNumber'] as String? ?? '',
      providerNpiOrId: json['providerNpiOrId'] as String? ?? '',
      providerOrganization: json['providerOrganization'] as String? ?? '',
      consentedAt: _parseInstant(json['consentedAt']),
    );
  }

  static DateTime? _parseInstant(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}

/// Account-scoped store for clinical sandbox opt-in state.
class ClinicalConsentStore {
  ClinicalConsentStore(this._prefs);

  static const prefsKey = 'clinical_sandbox_consent_v1';

  final MobilePrefsStore _prefs;

  ClinicalConsentState _cached = const ClinicalConsentState.denied();
  bool _hydrated = false;

  ClinicalConsentState get cached => _cached;

  Future<ClinicalConsentState> current() async {
    if (!_hydrated) {
      await hydrate();
    }
    return _cached;
  }

  Future<void> hydrate() async {
    final map = await _prefs.readJsonMap(prefsKey);
    _cached = ClinicalConsentState.fromJson(map);
    _hydrated = true;
  }

  Future<void> save(ClinicalConsentState state) async {
    await _prefs.writeJsonMap(prefsKey, state.toJson());
    _cached = state;
    _hydrated = true;
  }

  Future<void> revoke() async {
    await save(const ClinicalConsentState.denied());
  }
}