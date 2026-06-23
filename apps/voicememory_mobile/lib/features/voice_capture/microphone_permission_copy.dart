/// User-facing copy when microphone permission blocks voice capture.
import '../archive_proof/visible_archive_proof_copy.dart';

abstract class MicrophonePermissionCopy {
  MicrophonePermissionCopy._();

  static const String deniedTitle = 'Microphone access is off';
  static const String deniedBody =
      'Microphone access is off. Turn it on in Settings, or type instead.';

  static const String openSettingsCta = 'Open Settings';
  static const String allowMicrophoneCta = 'Allow microphone';
  static const String typeInsteadCta = VisibleArchiveProofCopy.typeInsteadCta;

  static const String statusBlocked = 'Microphone blocked';

  static const String simulatorHelper =
      'In Simulator, reset privacy permissions or use Type instead.';

  static const String typeInsteadBlockedHelper =
      'Save your first moment as text — no microphone needed.';
}
