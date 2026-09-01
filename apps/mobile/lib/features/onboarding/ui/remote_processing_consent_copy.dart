import 'package:archiveme_mobile/features/trust/privacy_screen_copy.dart';

/// First-run send-choice copy — screen 2 of onboarding.
///
/// This screen's only job is the decision. Architecture, storage
/// protection, and the on-device-only switch belong in Privacy settings.
abstract final class RemoteProcessingConsentCopy {
  RemoteProcessingConsentCopy._();

  static const String title =
      'New moments can stay on this phone, or leave for a transcript.';

  static const String body =
      'Sending gives you a written transcript and a short read on whether '
      'this may have shown up before. Off is where you start. Already-saved '
      'moments are not sent.';

  /// Privacy-screen wording, aliased so the duplication gate sees a
  /// reference. First-run renders [body], not this essay.
  static const String lede = PrivacyScreenCopy.whereWordsGoBody;

  static const String changeLaterFootnote =
      'You can change this later in Privacy.';

  static const String allowCta = 'Send new moments for a transcript';
  static const String declineCta = 'Keep saves on this phone';

  // ——— Not shown on first-run. Kept so grant-effect and privacy tests
  // can still name the switch and the grant scope. ———

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

  static const String settingChangeHeading = 'What this button changes';

  /// Says that granting also turns the Settings switch off.
  ///
  /// Not rendered on first-run. [OnboardingRemoteProcessingDecision] still
  /// performs this when the customer grants.
  static const String settingChangeBody =
      'This app also has an on-device-only switch in Settings → Privacy. '
      'While that switch is on, remote processing stays off even with your '
      'permission on record. If it is on, choosing '
      '"$allowCta" '
      'here turns it off for you, and you can turn it back on there any time '
      'you want remote work to stop.';

  static const String settingChangeScope =
      'This covers transcription and reflection for moments you save from '
      'here on. Recordings you have already saved are not sent by this '
      'choice, and it grants those two purposes rather than a general '
      'permission.';

  static const String declinedFootnote = changeLaterFootnote;

  static const String moreDetailLink = 'See what is sent and when';
}
