/// User-facing copy for the first-use remote-processing consent step,
/// shown once at the end of onboarding, before anything is ever sent off
/// the device for AI analysis.
abstract final class RemoteProcessingConsentCopy {
  RemoteProcessingConsentCopy._();

  static const String title = 'Before your first save';

  static const String body =
      'Saving a moment always stays on this device, even if you say no '
      'below. Turning this on lets ArchiveMe send that moment\'s transcript '
      'to our servers so it can compare it against what you\'ve said before '
      'and hand back a reflection — that comparison is the whole point of '
      'the app, and it can only happen off-device.';

  static const String detailBullet1 =
      'What gets sent: only the text of what you said, not the audio '
      'recording itself.';

  static const String detailBullet2 =
      'What comes back: a short reflection on whether this repeats '
      'something you\'ve said before.';

  static const String detailBullet3 =
      'You can turn this off any time in Settings → Privacy. Off means '
      'every new moment stays local-only until you turn it back on.';

  static const String allowCta = 'Yes, compare my moments';
  static const String declineCta = 'Not now — keep this on my device';

  static const String declinedFootnote =
      'You can still record and save. Moments just won\'t get compared '
      'until you turn this on in Settings → Privacy.';
}
