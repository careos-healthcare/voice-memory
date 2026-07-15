import '../features/onboarding/first_session_onboarding_copy.dart';
import '../features/timeline_positioning/timeline_positioning_copy.dart';

/// Deeper loop education — shown from Record “How it works”, not on first screen.
abstract final class RecordHowItWorksCopy {
  RecordHowItWorksCopy._();

  static const sheetTitle = 'How it works';

  static const steps = FirstSessionOnboardingCopy.steps;

  static const chatGptLine = FirstSessionOnboardingCopy.notChatFootnote;

  static const timelineHeading = 'Timeline';

  static const timelineBullets = TimelinePositioningCopy.timelineBullets;

  static const doneLabel = 'Done';
}
