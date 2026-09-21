import 'package:archiveme_mobile/features/onboarding/ui/onboarding_v1_copy.dart';

/// Confirmation after the remote-processing choice — the last onboarding
/// screen before `/record`.
///
/// This screen's only job is to say what the customer just chose, then let
/// them start. Architecture, storage status, analytics, and the privacy
/// link already had their screen.
abstract final class OnDeviceHeroCopy {
  OnDeviceHeroCopy._();

  static const String allowedTitle = 'New moments can be sent for a read';

  static const String allowedBody =
      'A transcript and a short read can leave this phone for moments you '
      'save from here on. You can turn remote processing off later.';

  static const String declinedTitle = 'New moments stay on this device';

  static const String declinedBody =
      'You can still record and save. Nothing is sent for new moments until '
      'you turn remote processing on later.';

  static String titleFor({required bool allowedRemote}) =>
      allowedRemote ? allowedTitle : declinedTitle;

  static String bodyFor({required bool allowedRemote}) =>
      allowedRemote ? allowedBody : declinedBody;

  static const String continueCta = OnboardingV1Copy.startCta;
}
