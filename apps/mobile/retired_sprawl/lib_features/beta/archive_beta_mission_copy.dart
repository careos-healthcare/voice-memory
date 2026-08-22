import 'package:archiveme_mobile/features/beta/tester_mission_copy.dart';

/// Copy for the lightweight TestFlight/beta mission card on Record.
abstract final class ArchiveBetaMissionCopy {
  ArchiveBetaMissionCopy._();

  static const String title = TesterMissionCopy.title;

  static const String mission = TesterMissionCopy.mission;

  static const List<String> steps = TesterMissionCopy.steps;

  static const String feedbackLine = TesterMissionCopy.feedbackQuestion;

  static const startCta = 'Start with one moment';
  static const hideCta = 'Hide this';
}