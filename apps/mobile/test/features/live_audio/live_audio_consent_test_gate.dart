import 'dart:io';

import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// A gate that permits live-audio streaming, for tests about something else.
///
/// `LiveAudioSessionCoordinator.connect` refuses without a permitted decision,
/// so tests covering reconnect, audio focus and capture lifecycle need one that
/// says yes. This subclass answers directly rather than reading real stores:
/// the on-device-only half of the real predicate lives in a static whose
/// default is platform-conditional and whose setter is async, which a
/// synchronous test builder cannot honestly arrange.
///
/// It is therefore a stub, and stubs that always say yes are how a consent
/// check gets tested into meaninglessness. The mitigation is that it is used
/// *only* where consent is not the subject. Every case that actually asserts
/// the gate's behaviour — refusal, purpose mismatch, the "Never send to server"
/// veto, withdrawal mid-session, and the positive control — lives in
/// `test/privacy/live_audio_streaming_consent_gate_test.dart` and builds the
/// real `RemoteProcessingConsentGate` over real stores with both halves set
/// explicitly. If you are reaching for this class to make a consent assertion
/// pass, the assertion belongs in that file instead.
class PermittingLiveAudioConsentGate extends RemoteProcessingConsentGate {
  PermittingLiveAudioConsentGate()
    : super(
        RemoteProcessingConsentStore(
          MobilePrefsStore(
            file: File(
              '${Directory.systemTemp.path}/live_audio_unused_prefs.json',
            ),
          ),
        ),
      );

  @override
  Future<bool> isPurposePermittedNow(RemoteProcessingPurpose purpose) async =>
      true;

  @override
  Future<RemoteProcessingConsentDecision> evaluateFor(
    RemoteProcessingPurpose purpose,
  ) async => RemoteProcessingConsentDecision(
    purpose: purpose,
    permitted: true,
    consentAtProcessingTime: true,
    currentPermission: true,
    onDeviceProcessingOnly: false,
  );
}
