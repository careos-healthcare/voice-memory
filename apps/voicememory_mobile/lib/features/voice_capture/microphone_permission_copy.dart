import '../archive_proof/visible_archive_proof_copy.dart';
import '../trust/capture_recovery_copy.dart';

/// User-facing copy when microphone permission blocks voice capture.
abstract class MicrophonePermissionCopy {
  MicrophonePermissionCopy._();

  static const String neededTitle = 'Record with your voice';

  static const String neededBody =
      'ArchiveMe saves short moments in your own words. '
      'Ten seconds is enough.';

  static const String softPromptTitle = 'Use your voice to journal';
  static const String softPromptBody =
      'Microphone access lets you capture a journal entry by speaking.';
  static const String softPromptPrivacy =
      'Your recording stays in app-private storage while it is processed. '
      'Offline transcription stays on this device.';
  static const String notNowCta = 'Not now';

  /// Alias for blocked-panel title — same calm framing when access is denied.
  static const String deniedTitle =
      'ArchiveMe needs your microphone to transcribe and save your thoughts.';

  static const String deniedBody =
      'To start your First Three Journey, enable microphone access in your '
      'device settings. Recordings stay in app-private storage while they are '
      'processed. Online transcription may securely send audio to the '
      'ArchiveMe transcription service.';

  static const String whyMicrophoneTitle = 'Why do we need this?';
  static const String localWhisperDetail =
      'Offline transcription uses Whisper on this device when available.';
  static const String privacyDetail =
      'Raw audio is never included in analytics, and typed journaling remains '
      'available without microphone access.';
  static const String connectedMessage =
      'Microphone connected. Tap to begin recording.';

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
