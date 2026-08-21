import 'package:archiveme_mobile/features/onboarding/first_session_onboarding_copy.dart';
import 'package:archiveme_mobile/features/timeline_positioning/timeline_positioning_copy.dart';

/// Deeper loop education — shown from Record “How it works”, not on first screen.
abstract final class RecordHowItWorksCopy {
  RecordHowItWorksCopy._();

  static const sheetTitle = 'How it works';

  static const List<({String body, String title})> steps = FirstSessionOnboardingCopy.steps;

  static const String chatGptLine = FirstSessionOnboardingCopy.notChatFootnote;

  static const timelineHeading = 'Timeline';

  static const List<String> timelineBullets = TimelinePositioningCopy.timelineBullets;

  static const doneLabel = 'Done';
}