import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Result of a consent check at a remote-processing boundary.
class RemoteProcessingConsentDecision {
  const RemoteProcessingConsentDecision({
    required this.permitted,
    required this.consentAtProcessingTime,
    required this.currentPermission,
    required this.onDeviceProcessingOnly,
    required this.purpose,
  });

  final RemoteProcessingPurpose purpose;

  /// Whether this specific remote attempt may proceed now.
  final bool permitted;

  /// Snapshot of purpose permission when the check ran (for proof admission).
  final bool consentAtProcessingTime;

  /// Live permission from the account-scoped consent store for [purpose].
  ///
  /// This is consent alone. It says nothing about whether the attempt may
  /// proceed — read [permitted] for that, and use this only to explain the
  /// decision on settings and audit surfaces.
  final bool currentPermission;

  /// Whether "Never send to server" was on when the check ran.
  final bool onDeviceProcessingOnly;
}

/// Central gate for remote transcription, analysis, and recovery uploads.
///
/// This is the single authoritative answer to "may this leave the device for
/// [RemoteProcessingPurpose]?". Two independent conditions must both hold, and
/// the product copy promises both:
///
/// 1. [OnDeviceProcessingStore] ("Never send to server") is off. Its default
///    for a customer who has not chosen is platform-conditional — see
///    `OnDeviceProcessingStore.defaultEnabled` — and whatever it resolves to,
///    it is an absolute veto: a granted consent record cannot override it.
/// 2. The customer granted that specific purpose.
///
/// Call sites must not recompose these conditions themselves.
/// `RemoteProcessingConsentStore.isPurposeGrantedNow` answers only half the
/// question, and a call site that reaches for it directly re-opens the gap
/// between what the toggle promises and what the app does.
class RemoteProcessingConsentGate {
  RemoteProcessingConsentGate(this._store);

  RemoteProcessingConsentGate.fromPrefs(MobilePrefsStore prefs)
    : _store = RemoteProcessingConsentStore(prefs);

  final RemoteProcessingConsentStore _store;

  Future<RemoteProcessingConsentDecision> evaluateFor(
    RemoteProcessingPurpose purpose,
  ) async {
    final onDeviceOnly = await _onDeviceProcessingOnly();
    final state = await _store.current();
    final consented = state.isPurposeGranted(purpose);
    final permitted = consented && !onDeviceOnly;
    return RemoteProcessingConsentDecision(
      purpose: purpose,
      permitted: permitted,
      consentAtProcessingTime: permitted,
      currentPermission: consented,
      onDeviceProcessingOnly: onDeviceOnly,
    );
  }

  /// Adapter for call sites that gate reflection/analysis only.
  Future<RemoteProcessingConsentDecision> evaluate() =>
      evaluateFor(RemoteProcessingPurpose.remoteReflection);

  Future<bool> isPermittedNow() =>
      isPurposePermittedNow(RemoteProcessingPurpose.remoteReflection);

  /// The predicate every remote boundary should call. Fails closed.
  Future<bool> isPurposePermittedNow(RemoteProcessingPurpose purpose) async {
    try {
      return (await evaluateFor(purpose)).permitted;
    } on Object {
      // ignore: silent_catch_audit — an unreadable setting must not be read as
      // permission to upload.
      return false;
    }
  }

  static Future<bool> _onDeviceProcessingOnly() async {
    try {
      await OnDeviceProcessingStore.ensureLoaded();
      return OnDeviceProcessingStore.enabled;
    } on Object {
      // ignore: silent_catch_audit — fail closed. Not `defaultEnabled`: that
      // is off on Android, so reading it here would fail open.
      return OnDeviceProcessingStore.failClosedEnabled;
    }
  }
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
