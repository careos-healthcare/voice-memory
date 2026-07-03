import 'tester_mission_copy.dart';

/// Copy for the lightweight TestFlight/beta mission card on Record.
abstract final class ArchiveBetaMissionCopy {
  ArchiveBetaMissionCopy._();

  static const title = TesterMissionCopy.title;

  static const mission = TesterMissionCopy.mission;

  static const steps = TesterMissionCopy.steps;

  static const feedbackLine = TesterMissionCopy.feedbackQuestion;

  static const startCta = 'Start with one moment';
  static const hideCta = 'Hide this';
}
