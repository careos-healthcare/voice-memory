/// User-facing copy for the first-use remote-processing consent step,
/// shown once at the end of onboarding, before anything is ever sent off
/// the device for transcription or reflection.
abstract final class RemoteProcessingConsentCopy {
  RemoteProcessingConsentCopy._();

  static const String title = 'Saving on this device';

  static const String body =
      'Saving always works on this device, even if you choose not to use '
      'remote processing below. Nothing is sent until you choose remote '
      'processing here or turn it on later in Settings → Privacy.';

  static const String detailBullet1 =
      'What gets sent when on: your audio recording for transcription, '
      'then the transcript text for reflection.';

  static const String detailBullet2 =
      'What comes back: a written transcript (when needed) and a short '
      'reflection on whether this repeats something you have said before.';

  static const String detailBullet3 =
      'You can turn this off any time in Settings → Privacy. Off means '
      'nothing is sent for new moments — audio and text stay on this device.';

  static const String allowCta = 'Use remote processing';
  static const String declineCta = 'Keep saves on this device only';

  static const String declinedFootnote =
      'You can still record and save. New moments stay on this device until '
      'you turn remote processing on in Settings → Privacy.';

  static const String moreDetailLink = 'See what is sent and when';
}
