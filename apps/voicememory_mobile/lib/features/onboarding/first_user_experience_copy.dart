import '../../product/consumer_ui_copy.dart';
import '../../security/privacy_copy_policy.dart';

/// Canonical first-run copy — one ArchiveMe explanation and one primary action.
abstract class FirstUserExperienceCopy {
  FirstUserExperienceCopy._();

  static const String introTitle = 'Notice what keeps repeating';
  static const String introBody =
      'ArchiveMe helps you notice what keeps repeating in your own words. '
      'Start with one honest moment.';
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
