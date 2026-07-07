import '../../features/landing_continuity/landing_app_continuity_copy.dart';
import '../../product/consumer_ui_copy.dart';
import '../../security/privacy_copy_policy.dart';

/// Canonical first-run copy — one ArchiveMe explanation and one primary action.
abstract class FirstUserExperienceCopy {
  FirstUserExperienceCopy._();

  static const String introTitle = LandingAppContinuityCopy.hero;
  static const String introBody =
      'Save small moments when something stands out. ArchiveMe turns them into '
      'a private timeline in your own words. Start with one honest moment.';
  static const String primaryCta = ConsumerUiCopy.recordOneMomentCta;

  static const String trustLine = PrivacyCopyPolicy.personalNotMedicalDisclaimer;

  /// Returning-user session survey — must never render on an empty archive.
  static const String returnSessionSurveyTitle = 'What brought you back today?';

  static const List<String> all = [
    introTitle,
    introBody,
    primaryCta,
    trustLine,
    returnSessionSurveyTitle,
  ];
}
