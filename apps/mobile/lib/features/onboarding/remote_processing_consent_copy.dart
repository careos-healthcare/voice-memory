/// User-facing copy for the first-use remote-processing consent step,
/// shown once at the end of onboarding, before anything is ever sent off
/// the device for transcription or reflection.
abstract final class RemoteProcessingConsentCopy {
  RemoteProcessingConsentCopy._();

  static const String title = 'Before your first save';

  static const String body =
      'Saving a moment always stays on this device, even if you say no '
      'below. Turning this on lets ArchiveMe send your recording and its '
      'transcript to our servers so it can transcribe what you said and '
      'compare it against what you have said before — that comparison is '
      'the whole point of the app, and it can only happen off-device.';

  static const String detailBullet1 =
      'What gets sent when on: your audio recording for transcription, '
      'then the transcript text for reflection.';

  static const String detailBullet2 =
      'What comes back: a written transcript (when needed) and a short '
      'reflection on whether this repeats something you have said before.';

  static const String detailBullet3 =
      'You can turn this off any time in Settings → Privacy. Off means '
      'nothing is sent for new moments — audio and text stay on this device.';

  static const String allowCta = 'Yes, compare my moments';
  static const String declineCta = 'Not now — keep this on my device';

  static const String declinedFootnote =
      'You can still record and save. New moments stay on this device until '
      'you turn remote processing on in Settings → Privacy.';
}
