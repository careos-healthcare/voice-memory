import 'beta_invite_models.dart';
import '../capacity_loop/capacity_three_moment_copy.dart';
import '../capacity_loop/capacity_activation_fit_copy.dart';

/// Copy for beta tester invite packs — crisp, local-only recruitment scripts.
abstract final class BetaInviteCopy {
  BetaInviteCopy._();

  static const corePositioning =
      'ArchiveMe shows what keeps repeating across your saved moments.';

  static const screenTitle = 'Invite a beta tester';
  static const subtitle =
      'Send someone a clear task so you can see whether ArchiveMe makes sense '
      'by their third saved moment.';

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
      'Copy invite scripts and a simple 3-moment tester task.';
  static const openBetaInviteButton = 'Open beta invite pack';

  static const helpTitle = 'Beta invite pack';
  static const helpBody =
      'Use invite scripts to recruit testers for the 3-moment archive loop. '
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

  static const capacityYesBetaTaskLine = CapacityThreeMomentCopy.betaTaskLine;
  static const capacityActivationFitBetaLine =
      CapacityActivationFitCopy.betaTaskLine;

  static const testerTask =
      'Save 3 moments. After the third, open Archive and answer whether '
      'ArchiveMe showed something useful.';

  static const betaSuccessChecklist =
      'Beta success means: save 3 real moments, return once, review what '
      'repeated, tell us if it fits, and say whether you would pay to keep '
      'this archive.';

  static const reportBackPrompt =
      'Did you understand the app? Did it show anything useful by entry 3? '
      'Would you pay to keep a long-term archive of this pattern?';

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
      'I\'m testing ArchiveMe — a private app that helps you see what keeps '
      'repeating across your saved moments. The test is simple: save 3 moments '
      'this week and tell me if the archive shows anything useful.';

  static const _shortWorkPatterns =
      'I\'m testing ArchiveMe for people who keep saying yes when they have '
      'no capacity. Save 3 real moments this week — especially yes moments — '
      'and tell me if the archive shows what keeps repeating by the third.';

  static const _shortJournalingUpgrade =
      'I\'m testing ArchiveMe for people who already journal but want evidence '
      'over time. Save 3 moments this week and tell me if the archive compares '
      'them usefully.';

  static const _shortFounderCreator =
      'I\'m testing ArchiveMe for people who make repeated decisions and want '
      'to see patterns across saved moments. Save 3 moments this week and tell '
      'me if the archive shows anything useful.';

  static const _shortPrivateArchive =
      'I\'m testing ArchiveMe as a private archive for reflection without '
      'sharing entries. Save 3 moments this week and tell me if the archive '
      'shows anything useful by the third.';

  static const _longGeneral =
      'ArchiveMe is for people who want to notice what keeps repeating across '
      'their own saved moments — not as a conclusion, but as cautious evidence '
      'you can review over time.';

  static const _longWorkPatterns =
      'ArchiveMe is a private evidence archive for overcommitment patterns — '
      'save when you say yes too fast, then compare what keeps repeating in '
      'your own words.';

  static const _longJournalingUpgrade =
      'If you already journal, ArchiveMe is meant to turn saved moments into a '
      'comparable archive instead of a pile of one-off notes.';

  static const _longFounderCreator =
      'ArchiveMe is for people who make repeated decisions and want a longer '
      'view of what their own saved moments keep pointing to.';

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
'''.trim();
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
