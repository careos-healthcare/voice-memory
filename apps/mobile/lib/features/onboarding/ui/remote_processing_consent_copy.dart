/// User-facing copy for the first-use remote-processing consent step.
abstract final class RemoteProcessingConsentCopy {
  RemoteProcessingConsentCopy._();

  static const String title = 'Processing on this device first';

  static const String body =
      'Saving always works on this device. Language models run locally here '
      'first. Nothing is sent for transcription or reflection until you choose '
      'remote processing below or turn it on later in Settings → Privacy.';

  static const String detailBullet1 =
      'When remote processing is on: your audio may be sent for transcription, '
      'then transcript text for reflection.';

  static const String detailBullet2 =
      'What comes back: a written transcript when needed and a short read on '
      'whether this may repeat something you said before.';

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
