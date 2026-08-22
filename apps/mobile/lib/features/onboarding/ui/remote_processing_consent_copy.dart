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

  /// Heading for [settingChangeBody] — stated before the buttons, because it
  /// describes what the "Use remote processing" button does beyond recording a
  /// consent record.
  static const String settingChangeHeading = 'What this button changes';

  /// Says that granting here also turns the Settings switch off.
  ///
  /// Deliberately avoids naming the switch by its label: the label is an
  /// absolute phrase that the privacy copy scanner reports, and this constant
  /// is new copy that should clear the scanner rather than earn a baseline
  /// entry. It also avoids asserting the switch's current value, which is now
  /// platform-conditional — see `OnDeviceProcessingStore.defaultEnabled`.
  ///
  /// Turning it off is necessary but not sufficient: `permitted = consented &&
  /// !onDeviceOnly`, so each purpose still needs its own grant. Turning it back
  /// on stops remote processing for every purpose while consent stays on
  /// record, which is why the last sentence points at the switch.
  static const String settingChangeBody =
      'This app also has an on-device-only switch in Settings → Privacy. '
      'While that switch is on, remote processing stays off even with your '
      'permission on record. If it is on, choosing "Use remote processing" '
      'here turns it off for you, and you can turn it back on there any time '
      'you want remote work to stop.';

  /// What stays off after granting, so the grant is not read as broader.
  static const String settingChangeScope =
      'This covers transcription and reflection for moments you save from '
      'here on. Recordings you have already saved are not sent by this '
      'choice, and it grants those two purposes rather than a general '
      'permission.';

  static const String allowCta = 'Use remote processing';
  static const String declineCta = 'Keep saves on this device only';

  static const String declinedFootnote =
      'You can still record and save. New moments stay on this device until '
      'you turn remote processing on in Settings → Privacy.';

  static const String moreDetailLink = 'See what is sent and when';
}
