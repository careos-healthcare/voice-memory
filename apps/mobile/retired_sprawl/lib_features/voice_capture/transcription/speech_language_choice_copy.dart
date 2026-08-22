/// Copy for the one-time question about which language the customer speaks.
///
/// Asked rather than detected. The app could read the phone's language setting
/// and never mention it, and for most people that would be right — but a
/// recogniser given the wrong language returns fluent, confident text rather
/// than an error, and this app quotes transcript excerpts back to people as
/// evidence about their own beliefs. Being wrong here does not look like being
/// wrong; it looks like a person saying something they never said. So the copy
/// says what the answer is used for and does not pretend a guess was made.
abstract final class SpeechLanguageChoiceCopy {
  SpeechLanguageChoiceCopy._();

  static const String title = 'Which language do you speak in here?';

  static const String body =
      'Writing out what you said happens on this device, and the recogniser '
      'has to be told which language to expect. It is not read from your '
      'phone settings, because a recogniser given the wrong language does not '
      'stop — it produces confident text that is not what you said, and this '
      'app quotes your words back to you later.';

  static const String pickerLabel = 'Language spoken';

  static const String confirmCta = 'Use this language';

  static const String footnote =
      'You can change this in Settings → Privacy. Recordings you already saved '
      'keep their audio and can be written out again afterwards.';

  /// Shown when the customer's language is not in the list.
  static const String missingLanguageNote =
      'If your language is not listed, this build cannot write it out on the '
      'device yet. Saving still keeps the audio.';
}
