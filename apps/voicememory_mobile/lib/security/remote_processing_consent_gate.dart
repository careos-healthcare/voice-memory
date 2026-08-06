import '../../features/proof_admission/remote_processing_consent_store.dart';
import '../../storage/mobile_prefs_store.dart';

/// Result of a consent check at a remote-processing boundary.
class RemoteProcessingConsentDecision {
  const RemoteProcessingConsentDecision({
    required this.permitted,
    required this.consentAtProcessingTime,
    required this.currentPermission,
  });

  /// Whether this specific upload/transcription attempt may proceed now.
  final bool permitted;

  /// Snapshot of consent state when the check ran (for proof admission).
  final bool consentAtProcessingTime;

  /// Live permission from the account-scoped consent store.
  final bool currentPermission;
}

/// Central gate for remote transcription, analysis, and recovery uploads.
///
/// Recheck immediately before every remote upload and after queue resume or
/// account/session changes.
class RemoteProcessingConsentGate {
  RemoteProcessingConsentGate(this._store);

  RemoteProcessingConsentGate.fromPrefs(MobilePrefsStore prefs)
      : _store = RemoteProcessingConsentStore(prefs);

  final RemoteProcessingConsentStore _store;

  Future<RemoteProcessingConsentDecision> evaluate() async {
    final state = await _store.current();
    return RemoteProcessingConsentDecision(
      permitted: state.consented,
      consentAtProcessingTime: state.consented,
      currentPermission: state.consented,
    );
  }

  Future<bool> isPermittedNow() async => (await evaluate()).permitted;
}

/// Thrown when a remote upload is attempted without active consent.
class RemoteProcessingConsentRequired implements Exception {
  const RemoteProcessingConsentRequired();
  @override
  String toString() => 'RemoteProcessingConsentRequired';
}
