import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Result of a consent check at a remote-processing boundary.
class RemoteProcessingConsentDecision {
  const RemoteProcessingConsentDecision({
    required this.permitted,
    required this.consentAtProcessingTime,
    required this.currentPermission,
    required this.purpose,
  });

  final RemoteProcessingPurpose purpose;

  /// Whether this specific remote attempt may proceed now.
  final bool permitted;

  /// Snapshot of purpose permission when the check ran (for proof admission).
  final bool consentAtProcessingTime;

  /// Live permission from the account-scoped consent store for [purpose].
  final bool currentPermission;
}

/// Central gate for remote transcription, analysis, and recovery uploads.
class RemoteProcessingConsentGate {
  RemoteProcessingConsentGate(this._store);

  RemoteProcessingConsentGate.fromPrefs(MobilePrefsStore prefs)
    : _store = RemoteProcessingConsentStore(prefs);

  final RemoteProcessingConsentStore _store;

  Future<RemoteProcessingConsentDecision> evaluateFor(
    RemoteProcessingPurpose purpose,
  ) async {
    final state = await _store.current();
    final permitted = state.isPurposeGranted(purpose);
    return RemoteProcessingConsentDecision(
      purpose: purpose,
      permitted: permitted,
      consentAtProcessingTime: permitted,
      currentPermission: permitted,
    );
  }

  /// Adapter for call sites that gate reflection/analysis only.
  Future<RemoteProcessingConsentDecision> evaluate() =>
      evaluateFor(RemoteProcessingPurpose.remoteReflection);

  Future<bool> isPermittedNow() async =>
      (await evaluateFor(RemoteProcessingPurpose.remoteReflection)).permitted;

  Future<bool> isPurposePermittedNow(RemoteProcessingPurpose purpose) async =>
      (await evaluateFor(purpose)).permitted;
}

/// Thrown when a remote upload is attempted without active consent.
class RemoteProcessingConsentRequired implements Exception {
  const RemoteProcessingConsentRequired([this.purpose]);

  final RemoteProcessingPurpose? purpose;

  @override
  String toString() => purpose == null
      ? 'RemoteProcessingConsentRequired'
      : 'RemoteProcessingConsentRequired($purpose)';
}
