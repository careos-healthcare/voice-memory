/// Copy for contextual privacy reassurance on strong archive surfaces.
abstract final class ContextualPrivacyCopy {
  ContextualPrivacyCopy._();

  static const fullLine =
      'Only you see this archive on this device. You can delete a moment or remove it from a pattern.';

  static const compactLine =
      'You stay in control: delete a moment or remove it from a pattern.';

  static const yourControlsLink = 'Your controls';

  static List<String> allVisibleStrings() => [
    fullLine,
    compactLine,
    yourControlsLink,
  ];
}
