import 'package:archiveme_mobile/features/landing_continuity/landing_app_continuity_copy.dart';

/// Early-record guidance copy — mirrors the public landing promise.
abstract final class ThreeDayChallengeCopy {
  ThreeDayChallengeCopy._();

  static const String title = LandingAppContinuityCopy.hero;

  static const String day1Title = LandingAppContinuityCopy.step1Title;
  static const String day1Body = LandingAppContinuityCopy.step1Body;

  static const String day2Title = LandingAppContinuityCopy.step2Title;
  static const String day2Body = LandingAppContinuityCopy.step2Body;

  static const String day3Title = LandingAppContinuityCopy.step3Title;
  static const String day3Body = LandingAppContinuityCopy.step3Body;

  static const completionBody =
      'You gave ArchiveMe enough to compare what returned.';

  static const List<String> all = [
    title,
    LandingAppContinuityCopy.subheadline,
    day1Title,
    day1Body,
    day2Title,
    day2Body,
    day3Title,
    day3Body,
    completionBody,
  ];
}