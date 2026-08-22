import 'package:archiveme_mobile/features/beta_invite/beta_invite_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_activation_fit_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_three_moment_copy.dart';
import 'package:archiveme_mobile/features/landing_continuity/landing_app_continuity_copy.dart';

/// Copy for beta tester invite packs — crisp, local-only recruitment scripts.
abstract final class BetaInviteCopy {
  BetaInviteCopy._();

  static const corePositioning =
      'Save small moments when something stands out. ArchiveMe shows what keeps returning.';

  static const screenTitle = 'Invite a beta tester';
  static const subtitle =
      'Send someone a clear task so you can see whether ArchiveMe makes sense '
      'after a few saved moments.';

  static const variantSectionTitle = 'Invite variant';
  static const previewSectionTitle = 'Invite preview';
  static const privacyReminder = 'Do not share private entries.';

  static const copyShortButton = 'Copy short invite';
  static const copyFullButton = 'Copy full invite';
  static const copyTaskButton = 'Copy tester task';
  static const openBetaOutcomesButton = 'Open beta outcomes';
  static const openProInterestButton = 'Open Pro interest';

  static const shortCopied = 'Short invite copied';
  static const fullCopied = 'Full invite copied';
  static const taskCopied = 'Tester task copied';

  static const supportTitle = 'Invite beta tester';
  static const supportSubtitle =
      'Copy invite scripts and a simple early-archive tester task.';
  static const openBetaInviteButton = 'Open beta invite pack';

  static const helpTitle = 'Beta invite pack';
  static const helpBody =
      'Use invite scripts to recruit testers for the early archive loop. '
      'Nothing is uploaded from this screen.';

  static const betaOutcomesTotalLabel = 'Beta invites copied';
  static const betaOutcomesLastVariantLabel = 'Most recent invite variant';
  static const betaOutcomesTaskCopiedLabel = 'Tester task copied';
  static const betaOutcomesNoneLabel = 'none yet';

  static const variantGeneralTitle = 'General';
  static const variantWorkPatternsTitle = 'Work patterns';
  static const variantJournalingUpgradeTitle = 'Journaling upgrade';
  static const variantFounderCreatorTitle = 'Founder / creator';
  static const variantPrivateArchiveTitle = 'Private archive';

  static const String capacityYesBetaTaskLine = CapacityThreeMomentCopy.betaTaskLine;
  static const String capacityActivationFitBetaLine =
      CapacityActivationFitCopy.betaTaskLine;

  static const testerTask =
      'Save a few small moments when something stands out. After the third, open '
      'Archive and answer whether ArchiveMe showed what returned.';

  static const betaSuccessChecklist =
      'Beta success means: save a few real moments, return when something stands out, '
      'review what returned, tell us if it fits, and say whether you would pay to keep '
      'the longer proof trail.';

  static const reportBackPrompt =
      'Did you understand the app? Did it show anything useful by the third moment? '
      'Would you pay to keep the longer proof trail over time?';

  static const loopCardTitle = 'Know one person who would test this?';
  static const loopCardBody =
      'ArchiveMe works best when someone saves a few real moments and comes back when something returns.';
  static const loopCta = 'Copy beta invite';
  static const loopSecondary = 'Not now';
  static const loopInviteText =
      'Want to test ArchiveMe? It is a private timeline app. You save small moments when something stands out, and it shows what returns, changes, or fades over time. No daily journal required.';
  static const loopCopiedConfirmation = 'Beta invite copied';

  static const loopBannedPrivateTerms = <String>[
    'transcript',
    'journal entry',
    'private entry',
    'your words',
  ];

  static const loopBannedEvidenceTerms = <String>[
    'locked',
    'testimonial',
    'users say',
  ];

  static List<String> loopDisplayedStrings() => [
    loopCardTitle,
    loopCardBody,
    loopCta,
    loopSecondary,
    loopInviteText,
    loopCopiedConfirmation,
  ];

  static String variantTitle(BetaInviteVariantId id) => switch (id) {
    BetaInviteVariantId.general => variantGeneralTitle,
    BetaInviteVariantId.workPatterns => variantWorkPatternsTitle,
    BetaInviteVariantId.journalingUpgrade => variantJournalingUpgradeTitle,
    BetaInviteVariantId.founderCreator => variantFounderCreatorTitle,
    BetaInviteVariantId.privateArchive => variantPrivateArchiveTitle,
  };

  static String shortInvite(BetaInviteVariantId id) => switch (id) {
    BetaInviteVariantId.general => _shortGeneral,
    BetaInviteVariantId.workPatterns => _shortWorkPatterns,
    BetaInviteVariantId.journalingUpgrade => _shortJournalingUpgrade,
    BetaInviteVariantId.founderCreator => _shortFounderCreator,
    BetaInviteVariantId.privateArchive => _shortPrivateArchive,
  };

  static String longInvite(BetaInviteVariantId id) => switch (id) {
    BetaInviteVariantId.general => _longGeneral,
    BetaInviteVariantId.workPatterns => _longWorkPatterns,
    BetaInviteVariantId.journalingUpgrade => _longJournalingUpgrade,
    BetaInviteVariantId.founderCreator => _longFounderCreator,
    BetaInviteVariantId.privateArchive => _longPrivateArchive,
  };

  static const _shortGeneral =
      "I'm testing ArchiveMe — a private app that helps you see what keeps "
      'returning across your saved moments. The test is simple: save a few small '
      'moments when something stands out and tell me if the archive shows what returned.';

  static const _shortWorkPatterns =
      "I'm testing ArchiveMe for people who keep saying yes when they have "
      'no capacity. Save a few real moments when something stands out and tell me '
      'if the archive shows what returned by the third.';

  static const _shortJournalingUpgrade =
      "I'm testing ArchiveMe for people who already capture moments but want a "
      'timeline of what returned. Save a few small moments when something stands out '
      'and tell me if the archive compares them usefully.';

  static const _shortFounderCreator =
      "I'm testing ArchiveMe for people who make repeated decisions and want to "
      'see what keeps returning across saved moments. Save a few small moments and '
      'tell me if the archive shows anything useful.';

  static const _shortPrivateArchive =
      "I'm testing ArchiveMe as a private archive for reflection without "
      'sharing entries. Save a few small moments when something stands out and tell '
      'me if the archive shows what returned by the third.';

  static const String _longGeneral = LandingAppContinuityCopy.heroBody;

  static const _longWorkPatterns =
      'ArchiveMe is a private timeline for overcommitment patterns — save when '
      'something stands out, then compare what returned in your own words.';

  static const _longJournalingUpgrade =
      'If you already capture moments elsewhere, ArchiveMe is meant to turn saved '
      'moments into a timeline of what returned — not a daily journal project.';

  static const _longFounderCreator =
      'ArchiveMe is for people who make repeated decisions and want a longer view '
      'of what their own saved moments keep returning to.';

  static const _longPrivateArchive =
      'ArchiveMe keeps your archive local and private. Share-safe proof never '
      'includes raw entries — testers should keep their own moments private too.';

  static String fullInvite(BetaInviteVariantId id) {
    return '''
${shortInvite(id)}

${longInvite(id)}

Tester task:
$testerTask

What to report back:
$reportBackPrompt

$privacyReminder
'''
        .trim();
  }

  static List<String> allVisibleCopy() => [
    corePositioning,
    screenTitle,
    subtitle,
    variantSectionTitle,
    previewSectionTitle,
    privacyReminder,
    copyShortButton,
    copyFullButton,
    copyTaskButton,
    openBetaOutcomesButton,
    openProInterestButton,
    shortCopied,
    fullCopied,
    taskCopied,
    supportTitle,
    supportSubtitle,
    openBetaInviteButton,
    helpTitle,
    helpBody,
    betaOutcomesTotalLabel,
    betaOutcomesLastVariantLabel,
    betaOutcomesTaskCopiedLabel,
    betaOutcomesNoneLabel,
    variantGeneralTitle,
    variantWorkPatternsTitle,
    variantJournalingUpgradeTitle,
    variantFounderCreatorTitle,
    variantPrivateArchiveTitle,
    testerTask,
    reportBackPrompt,
    betaSuccessChecklist,
    capacityYesBetaTaskLine,
    capacityActivationFitBetaLine,
    ...BetaInviteVariantId.values.map(shortInvite),
    ...BetaInviteVariantId.values.map(longInvite),
  ];
}