import '../beta/tester_mission_copy.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import '../beta_invite/beta_invite_copy.dart';
import '../beta_outcomes/beta_outcomes_copy.dart';
import '../first_week_path/first_week_path_copy.dart';
import '../archive_calendar/archive_calendar_copy.dart';
import '../review_ritual/view_ritual_copy.dart';
import '../milestone_share/milestone_share_copy.dart';
import '../pro_value/pro_value_copy.dart';
import '../submission/app_store_submission_copy.dart';

/// Static copy for the in-app Help & reviewer guide.
abstract final class HelpReviewerGuideCopy {
  HelpReviewerGuideCopy._();

  static const screenTitle = 'Help & reviewer guide';

  static const settingsTitle = 'Help & reviewer guide';
  static const settingsSubtitle = 'Learn how to test ArchiveMe safely.';

  static const openSampleArchiveButton = 'Open Sample Archive';
  static const sampleArchiveHelpLink = 'Help & reviewer guide';
  static const supportFeedbackLink = 'Support & feedback';

  static const sectionWhatTitle = 'What ArchiveMe does';
  static const sectionWhatBulletOne =
      'ArchiveMe helps you save moments and see what repeats over time.';
  static const sectionWhatBulletTwo =
      'It shows cautious archive beliefs based on saved evidence.';

  static const sectionTypeInsteadTitle = 'How to test without microphone';
  static String get sectionTypeInsteadBulletOne =>
      'Use $typeInsteadLabel to save a written moment.';
  static const sectionTypeInsteadBulletTwo =
      'The app works even if microphone access is denied.';

  static const sectionQuickValueTitle = 'How to see the archive value quickly';
  static const sectionQuickValueBulletOne = 'Open Sample Archive.';
  static const sectionQuickValueBulletTwo = 'Follow the sample tour.';
  static const sectionQuickValueBulletThree = 'Open Evidence Map.';
  static const sectionQuickValueBulletFour = 'Try the demo share summary.';
  static const sectionQuickValueBulletFive =
      'For screenshots or review, use Sample Archive. It uses example data only.';

  static const sectionPrivacyTitle = 'Privacy basics';
  static const sectionPrivacyBulletOne =
      'Your archive is local to this device.';
  static const sectionPrivacyBulletTwo =
      'Share-safe proof does not include raw private entries.';
  static const sectionPrivacyBulletThree =
      'Export archive is explicit and asks you to review before sharing.';

  static const sectionExpectationsTitle = 'What not to expect';
  static const sectionExpectationsBulletOne = 'ArchiveMe does not diagnose.';
  static const sectionExpectationsBulletTwo = 'Beliefs are not conclusions.';
  static const sectionExpectationsBulletThree =
      'It is not a therapy or medical service.';

  static const sectionProLaterTitle = ProValueCopy.helpProLaterTitle;
  static const sectionProLaterNote = ProValueCopy.helpProLaterNote;

  static const helpBetaOutcomesTitle = BetaOutcomesCopy.helpSectionTitle;
  static const helpBetaOutcomesBody = BetaOutcomesCopy.helpSectionBody;

  static const helpFirstWeekPathTitle = FirstWeekPathCopy.helpSectionTitle;
  static const helpFirstWeekPathBullet = FirstWeekPathCopy.helpSectionBullet;

  static const helpBetaInviteTitle = BetaInviteCopy.helpTitle;
  static const helpBetaInviteBody = BetaInviteCopy.helpBody;

  static const helpBetaTesterTitle = TesterMissionCopy.title;
  static const helpBetaTesterMission = TesterMissionCopy.mission;
  static List<String> get helpBetaTesterBullets => [
        ...TesterMissionCopy.steps,
        TesterMissionCopy.feedbackQuestion,
      ];

  static String get typeInsteadLabel => VisibleArchiveProofCopy.typeInsteadCta;

  static List<HelpReviewerGuideSection> get sections => [
    HelpReviewerGuideSection(
      title: sectionWhatTitle,
      bullets: const [
        sectionWhatBulletOne,
        sectionWhatBulletTwo,
      ],
    ),
    HelpReviewerGuideSection(
      title: sectionTypeInsteadTitle,
      bullets: [
        sectionTypeInsteadBulletOne,
        sectionTypeInsteadBulletTwo,
      ],
    ),
    HelpReviewerGuideSection(
      title: sectionQuickValueTitle,
      bullets: const [
        sectionQuickValueBulletOne,
        sectionQuickValueBulletTwo,
        sectionQuickValueBulletThree,
        sectionQuickValueBulletFour,
        sectionQuickValueBulletFive,
      ],
    ),
    HelpReviewerGuideSection(
      title: helpFirstWeekPathTitle,
      bullets: const [helpFirstWeekPathBullet],
    ),
    HelpReviewerGuideSection(
      title: ArchiveCalendarCopy.helpSectionTitle,
      bullets: const [ArchiveCalendarCopy.helpSectionBullet],
    ),
    HelpReviewerGuideSection(
      title: ReviewRitualCopy.helpSectionTitle,
      bullets: const [ReviewRitualCopy.helpSectionBullet],
    ),
    HelpReviewerGuideSection(
      title: MilestoneShareCopy.helpSectionTitle,
      bullets: const [MilestoneShareCopy.helpSectionBullet],
    ),
    HelpReviewerGuideSection(
      title: AppStoreSubmissionCopy.suggestedReviewPathTitle,
      bullets: AppStoreSubmissionCopy.suggestedReviewPathBullets,
    ),
    HelpReviewerGuideSection(
      title: sectionPrivacyTitle,
      bullets: const [
        sectionPrivacyBulletOne,
        sectionPrivacyBulletTwo,
        sectionPrivacyBulletThree,
      ],
    ),
    HelpReviewerGuideSection(
      title: sectionProLaterTitle,
      bullets: const [sectionProLaterNote],
    ),
    HelpReviewerGuideSection(
      title: sectionExpectationsTitle,
      bullets: const [
        sectionExpectationsBulletOne,
        sectionExpectationsBulletTwo,
        sectionExpectationsBulletThree,
      ],
    ),
  ];
}

class HelpReviewerGuideSection {
  const HelpReviewerGuideSection({
    required this.title,
    required this.bullets,
  });

  final String title;
  final List<String> bullets;
}
