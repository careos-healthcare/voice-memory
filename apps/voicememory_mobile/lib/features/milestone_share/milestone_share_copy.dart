import '../archive_proof/visible_archive_proof_copy.dart';
import '../first_week_path/first_week_path_copy.dart';
import '../then_now/then_now_copy.dart';
import 'milestone_share_models.dart';

/// Share-safe milestone copy — fixed strings only, no journal text.
abstract final class MilestoneShareCopy {
  MilestoneShareCopy._();

  static const route = '/milestone-share-cards';
  static const recordRoute = '/record';
  static const archiveHomeRoute = '/archive-belief';

  static const eyebrow = 'Milestone cards';
  static const screenTitle = 'Milestone cards';
  static const screenIntro =
      'Share-safe proof of archive progress. No private entries, names, or quotes.';

  static const cardHeadline = 'Share your archive progress safely.';
  static const cardSummary =
      'Copy milestone proof without sharing what you said.';

  static const openMilestoneCardsCta = 'Open milestone cards';
  static const copyShareTextCta = 'Copy share text';
  static const copyTitleBodyCta = 'Copy title and body';
  static const shareCta = 'Share';
  static const copiedLabel = 'Copied';
  static const saveMomentCta = 'Save a moment';

  static const emptyTitle = 'No milestone cards yet';
  static const emptyBody =
      'Milestone cards appear after your first saved moment.';
  static const emptyCta = saveMomentCta;

  static const privacyFooter = VisibleArchiveProofCopy.shareProofPrivacyFooter;
  static const productLine = VisibleArchiveProofCopy.shareProofProductLine;

  static const supportSectionTitle = 'Milestone cards';
  static const supportSectionBody =
      'Copy share-safe proof of archive progress without private entry text.';

  static const helpSectionTitle = 'Milestone cards';
  static const helpSectionBullet =
      'Open Milestone cards to copy share-safe archive progress without private text.';

  static const betaOutcomesLabel = 'Share-safe milestone cards';
  static String betaOutcomesValue(int count) =>
      count <= 0 ? 'None yet' : '$count available';

  static const screenshotCardSummary =
      'Example milestone card — no private content.';

  static String shareTextFor(MilestoneShareCard card) =>
      [card.safeShareText, privacyFooter, productLine].join('\n');

  static String titleBodyFor(MilestoneShareCard card) =>
      '${card.title}\n${card.body}';

  static _MilestoneCardCopy cardFor(MilestoneShareId id) => switch (id) {
    MilestoneShareId.firstSavedMoment => (
      title: 'First saved moment',
      body: 'Your archive started with one honest save.',
      share: 'I saved my first moment in ArchiveMe.',
      proof: '1 moment saved',
      cta: saveMomentCta,
      route: recordRoute,
    ),
    MilestoneShareId.threeMomentsSaved => (
      title: 'Three moments saved',
      body: 'Enough to start noticing what might repeat.',
      share: 'I saved 3 moments and started seeing what might repeat.',
      proof: '3 moments saved',
      cta: openMilestoneCardsCta,
      route: route,
    ),
    MilestoneShareId.firstWatchThemeChosen => (
      title: 'First watch theme chosen',
      body: 'You picked something to watch across your archive.',
      share: 'I chose my first watch theme in ArchiveMe.',
      proof: 'Watch theme active',
      cta: openMilestoneCardsCta,
      route: route,
    ),
    MilestoneShareId.firstWeekPathComplete => (
      title: 'First week path complete',
      body: 'You finished the calm first-week return path.',
      share: 'I completed my first week path in ArchiveMe.',
      proof: '7-day path complete',
      cta: FirstWeekPathCopy.openPathCta,
      route: FirstWeekPathCopy.route,
    ),
    MilestoneShareId.firstWeeklyReview => (
      title: 'Weekly review ready',
      body: 'Your archive has enough to review the week calmly.',
      share: 'My archive is now strong enough for a weekly review.',
      proof: 'Weekly review available',
      cta: 'Open weekly review',
      route: '/weekly-archive-review',
    ),
    MilestoneShareId.firstRepeatingTheme => (
      title: 'First repeating theme',
      body: 'A theme showed up more than once in your archive.',
      share: 'ArchiveMe helped me notice my first repeating theme.',
      proof: 'Repeating theme found',
      cta: openMilestoneCardsCta,
      route: route,
    ),
    MilestoneShareId.firstThenVsNowAvailable => (
      title: 'Then vs Now available',
      body: 'You can compare earlier and newer saved moments.',
      share: 'I can now compare earlier and newer moments in ArchiveMe.',
      proof: 'Then vs Now available',
      cta: ThenNowCopy.reviewChangeCta,
      route: ThenNowCopy.route,
    ),
    MilestoneShareId.archiveCalendarActive => (
      title: 'Archive calendar active',
      body: 'Moments saved across more than one day this month.',
      share: 'I\'m building a private archive of what keeps repeating.',
      proof: 'Multiple active days',
      cta: 'Open archive calendar',
      route: '/archive-calendar',
    ),
  };

  static Iterable<String> get allVisibleStrings sync* {
    yield eyebrow;
    yield screenTitle;
    yield screenIntro;
    yield cardHeadline;
    yield cardSummary;
    yield openMilestoneCardsCta;
    yield copyShareTextCta;
    yield copyTitleBodyCta;
    yield shareCta;
    yield copiedLabel;
    yield saveMomentCta;
    yield emptyTitle;
    yield emptyBody;
    yield emptyCta;
    yield privacyFooter;
    yield productLine;
    yield supportSectionTitle;
    yield supportSectionBody;
    yield betaOutcomesLabel;
    yield screenshotCardSummary;
    for (final id in MilestoneShareId.values) {
      final copy = cardFor(id);
      yield copy.title;
      yield copy.body;
      yield copy.share;
      yield copy.proof;
      yield copy.cta;
    }
  }
}

typedef _MilestoneCardCopy = ({
  String title,
  String body,
  String share,
  String proof,
  String cta,
  String route,
});
