import '../../product/consumer_ui_copy.dart';
import '../archive_proof/visible_archive_proof_copy.dart';

/// Consumer copy for ArchiveMe's first-three-session product loop.
abstract class FirstThreeSessionCopy {
  FirstThreeSessionCopy._();

  // Session 1 — recorded something real.
  static const String session0Title = 'Start your archive';
  static const String session1CardTitle = 'You recorded something real.';
  static const String session1CardBody =
      'Add one more moment so ArchiveMe can compare what shows up again.';
  static const String session1NextAction = 'Add one more moment';
  static const String session1Title = VisibleArchiveProofCopy.firstSaveTitle;
  static const String session1Body = VisibleArchiveProofCopy.firstSaveBody;
  static const String session1EnoughForToday =
      VisibleArchiveProofCopy.firstSaveSecondary;
  static const String session1ReturnTomorrow =
      VisibleArchiveProofCopy.firstSaveReturnTomorrowBody;
  static const String session1ViewArchive =
      VisibleArchiveProofCopy.firstSaveViewArchiveCta;
  static const String session1RecordAnother =
      VisibleArchiveProofCopy.firstSavePrimaryCta;

  // Journey indicator (Record / Patterns).
  static const String journeyStep1 = 'Start your archive';
  static const String journeyStep2 = 'Notice what repeats';
  static const String journeyStep3 = 'Watch what changes';

  // Session 2 — two moments to compare, not a confirmed repeat.
  static const String session2StartingToNoticeTitle =
      VisibleArchiveProofCopy.twoEntryCompareTitle;
  static const String session2StartingToNoticeBody =
      VisibleArchiveProofCopy.twoEntryBodyUngrounded;
  static const String session2BodyGrounded =
      VisibleArchiveProofCopy.twoEntryBodyGrounded;
  static const String session2EvidenceLine =
      VisibleArchiveProofCopy.twoEntryCompareTitle;
  static const String session2NextAction =
      VisibleArchiveProofCopy.twoEntryNextAction;
  static const String session2PrimaryCta =
      VisibleArchiveProofCopy.twoEntryPrimaryCta;
  static const String session2ViewArchiveCta =
      VisibleArchiveProofCopy.twoEntryViewArchiveCta;

  // Session 3 — archive becoming useful.
  static const String session3Title =
      'Your archive is starting to show a thread.';
  static const String session3KeepsReturning =
      "Here's what keeps coming back.";
  static const String session3ChangedSince =
      "Here's what changed since last time.";
  static const String session3HonestMoment =
      'Your archive is more useful when you add one honest moment at a time.';

  // Soft Pro boundary (after repeat / archive value).
  static const String proTitle = 'Keep the longer proof trail.';
  static const String proBody =
      'Free shows the first useful proof. Pro keeps older evidence and longer archive history.';
  static const String proContinuityLine =
      'Free keeps recent proof. Pro keeps the longer proof trail over time.';
  static const String proCta = 'See Pro';
  static const String proSecondary = 'Not now';

  static String journeyLabelForCount(int reflectionCount) {
    if (reflectionCount <= 0) return journeyStep1;
    if (reflectionCount < 3) return journeyStep2;
    return journeyStep3;
  }

  static String journeyLabelForStepIndex(int stepIndex) {
    switch (stepIndex.clamp(0, 2)) {
      case 0:
        return journeyStep1;
      case 1:
        return journeyStep2;
      default:
        return journeyStep3;
    }
  }

  static const List<String> session1Lines = [
    session1Title,
    session1Body,
    session1EnoughForToday,
    session1ReturnTomorrow,
  ];

  static const List<String> session3Lines = [
    session3Title,
    session3KeepsReturning,
    session3ChangedSince,
    session3HonestMoment,
  ];

  static const List<String> proLines = [
    proTitle,
    proBody,
    proContinuityLine,
    proCta,
    proSecondary,
  ];

  static const List<String> bannedInternalTerms = [
    'revenuecat',
    'testflight',
    'entitlement',
    'upgrade required',
    'feature locked',
    'billing entitlement',
    'analysis complete',
    'insight generated',
    'ai detected',
  ];

  /// Session-2 repeat headline — shared with [ConsumerUiCopy].
  static String get session2RepeatTitle =>
      ConsumerUiCopy.secondSessionPossibleRepeatTitle;
}
