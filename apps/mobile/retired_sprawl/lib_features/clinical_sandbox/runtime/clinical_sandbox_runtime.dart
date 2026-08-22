import 'package:archiveme_mobile/features/clinical_sandbox/config/clinical_sandbox_feature_flags.dart';
import 'package:archiveme_mobile/features/clinical_sandbox/gates/clinical_consent_gate.dart';
import 'package:archiveme_mobile/features/clinical_sandbox/stores/clinical_consent_store.dart';
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show AppServices;
import 'package:archiveme_mobile/services/app_services.dart' show AppServices;
import 'package:meta/meta.dart';

/// Runtime orchestrator for the clinical sandbox — feature flag + consent cache.
abstract final class ClinicalSandboxRuntime {
  ClinicalSandboxRuntime._();

  static ClinicalConsentStore? _consentStore;
  static ClinicalConsentGate? _consentGate;
  static bool _consentPermitted = false;
  static bool _hydrated = false;

  static void bind({
    required ClinicalConsentStore consentStore,
    required ClinicalConsentGate consentGate,
  }) {
    _consentStore = consentStore;
    _consentGate = consentGate;
  }

  static ClinicalConsentGate? get consentGate => _consentGate;

  static ClinicalConsentStore? get consentStore => _consentStore;

  /// Call during [AppServices] bootstrap after prefs are available.
  static Future<void> hydrate() async {
    ClinicalSandboxFeatureFlags.assertSafeForPublicDistribution();
    if (!ClinicalSandboxFeatureFlags.isEnabled) {
      _consentPermitted = false;
      _hydrated = true;
      return;
    }

    final gate = _consentGate;
    if (gate == null) {
      _consentPermitted = false;
      _hydrated = true;
      return;
    }

    _consentPermitted = await gate.isPermittedNow();
    _hydrated = true;
  }

  /// Refresh consent cache after opt-in or revocation.
  static Future<void> refreshConsent() async {
    final gate = _consentGate;
    if (gate == null || !ClinicalSandboxFeatureFlags.isEnabled) {
      _consentPermitted = false;
      return;
    }
    _consentPermitted = await gate.isPermittedNow();
    _hydrated = true;
  }

  static bool get isFeatureEnabled => ClinicalSandboxFeatureFlags.isEnabled;

  static bool get isHydrated => _hydrated;

  /// True when biomarker enrichment and clinical interceptors may execute.
  static bool get mayRunClinicalAnalysis =>
      isFeatureEnabled && _consentPermitted;

  @visibleForTesting
  static void resetForTest() {
    _consentStore = null;
    _consentGate = null;
    _consentPermitted = false;
    _hydrated = false;
  }

  @visibleForTesting
  static void setConsentPermittedForTest(bool permitted) {
    _consentPermitted = permitted;
    _hydrated = true;
  }
}