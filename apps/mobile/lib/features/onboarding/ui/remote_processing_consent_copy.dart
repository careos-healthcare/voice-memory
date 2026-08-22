/// User-facing copy for the first-use remote-processing consent step.
abstract final class RemoteProcessingConsentCopy {
  RemoteProcessingConsentCopy._();

  static const String title = 'Processing on this device first';

  // The generic privacy paragraph that used to sit here was superseded by
  // OnDeviceArchitectureCopy, which the step now renders under its own
  // headings. That section states that remote processing is opt-in; the
  // bullets below are the operative disclosure of what the opt-in sends, so
  // they sit under [detailsHeading] rather than repeating the choice itself.

  static const String detailsHeading = 'If you turn it on';

  static const String detailBullet1 =
      'Your audio may be sent for transcription, then transcript text for '
      'reflection.';

  static const String detailBullet2 =
      'What comes back: a written transcript when needed and a short read on '
      'whether this may repeat something you said before.';

  static const String detailBullet3 =
      'Off is where you start, and where you can return: nothing is sent for '
      'new moments, and the switch lives in Settings → Privacy.';

  static const String allowCta = 'Use remote processing';
  static const String declineCta = 'Keep saves on this device only';

  static const String declinedFootnote =
      'You can still record and save. New moments stay on this device until '
      'you turn remote processing on in Settings → Privacy.';

  static const String moreDetailLink = 'See what is sent and when';
}
