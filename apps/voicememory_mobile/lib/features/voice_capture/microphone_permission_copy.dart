/// User-facing copy when microphone permission blocks voice capture.
library;

import '../archive_proof/visible_archive_proof_copy.dart';
import '../trust/capture_recovery_copy.dart';

abstract class MicrophonePermissionCopy {
  MicrophonePermissionCopy._();

  static const String neededTitle = 'Record with your voice';

  static const String neededBody =
      'ArchiveMe saves short moments in your own words. '
      'Ten seconds is enough.';

  /// Alias for blocked-panel title — same calm framing when access is denied.
  static const String deniedTitle = neededTitle;

  static const String deniedBody = CaptureRecoveryCopy.micDeniedBody;

  static const String openSettingsCta = 'Open Settings';

  /// Pre-system-prompt CTA — must not mimic Apple permission button wording.
  static const String requestMicrophoneCta = 'Use voice to record';

  @Deprecated('Use requestMicrophoneCta')
  static const String allowMicrophoneCta = requestMicrophoneCta;
  static const String typeInsteadCta = VisibleArchiveProofCopy.typeInsteadCta;

  static const String statusBlocked = 'Microphone blocked';

  /// Status while the system permission sheet is open — must not use Allow/OK.
  static const String statusRequesting = 'Preparing voice capture';

  static const String simulatorHelper = CaptureRecoveryCopy.simulatorMicHelper;

  static const String typeInsteadBlockedHelper =
      'Save your first moment as text — no microphone needed.';

  /// App Review 5.1.1 — pre-system-prompt CTAs must not mimic Apple dialogs.
  static const forbiddenPrePromptButtonWords = <String>[
    'Allow',
    'OK',
    'Grant',
    'Permit',
  ];

  static bool isAppleCompliantPrePromptCta(String cta) {
    final trimmed = cta.trim();
    if (trimmed.isEmpty) return false;
    for (final word in forbiddenPrePromptButtonWords) {
      if (trimmed.toLowerCase().startsWith(word.toLowerCase())) {
        return false;
      }
    }
    return true;
  }
}
