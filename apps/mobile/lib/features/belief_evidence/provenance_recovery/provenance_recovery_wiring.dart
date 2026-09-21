import 'package:archiveme_mobile/features/belief_evidence/provenance_recovery/provenance_recovery_adapter.dart';
import 'package:archiveme_mobile/features/belief_evidence/provenance_recovery/provenance_recovery_port.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Production construction for provenance recovery.
///
/// `ProvenanceRecoveryAction` keeps its default
/// [UnwiredProvenanceRecoveryPort] so tests and previews fail closed.
/// Use [port] / [planner] (or `ProvenanceRecoveryAction.production`) when
/// the app composition root is up. There is no production
/// `ProvenanceRecoveryAction` call site yet; this is the factory those
/// surfaces should use, including as `EvidenceCitationList.recoveryBuilder`.
abstract final class ProvenanceRecoveryWiring {
  ProvenanceRecoveryWiring._();

  /// Real adapter when AppServices / the bound container can supply deps,
  /// otherwise the unwired stub.
  static ProvenanceRecoveryPort port() =>
      ProvenanceRecoveryAdapter.tryFromBoundServices() ??
      const UnwiredProvenanceRecoveryPort();

  /// Live consent gate when AppServices is up; fail-closed otherwise.
  static ProvenanceRecoveryPlanner planner() {
    if (AppServices.isInitialized) {
      return ProvenanceRecoveryPlanner.fromGate(
        AppServices.instance.remoteProcessingConsentGate,
      );
    }
    return const ProvenanceRecoveryPlanner(readConsent: _failClosedConsent);
  }

  static Future<RemoteProcessingConsentDecision> _failClosedConsent() async {
    return const RemoteProcessingConsentDecision(
      purpose: RemoteProcessingPurpose.remoteTranscription,
      permitted: false,
      consentAtProcessingTime: false,
      currentPermission: false,
      onDeviceProcessingOnly: true,
    );
  }
}
