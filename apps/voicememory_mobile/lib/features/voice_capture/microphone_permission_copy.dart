/// User-facing copy when microphone permission blocks voice capture.
import '../archive_proof/visible_archive_proof_copy.dart';
import '../trust/capture_recovery_copy.dart';

abstract class MicrophonePermissionCopy {
  MicrophonePermissionCopy._();

  static const String neededTitle = 'Microphone access is needed';

  static const String neededBody =
      'ArchiveMe uses your voice to save short moments in your own words. '
      'Ten seconds is enough.';

  /// Alias for blocked-panel title — same calm framing when access is denied.
  static const String deniedTitle = neededTitle;

  static const String deniedBody = CaptureRecoveryCopy.micDeniedBody;

  static const String openSettingsCta = 'Open Settings';
  static const String allowMicrophoneCta = 'Allow microphone';
  static const String typeInsteadCta = VisibleArchiveProofCopy.typeInsteadCta;

  static const String statusBlocked = 'Microphone blocked';

  static const String simulatorHelper = CaptureRecoveryCopy.simulatorMicHelper;

  static const String typeInsteadBlockedHelper =
      'Save your first moment as text — no microphone needed.';
}
