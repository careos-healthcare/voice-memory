import 'package:archiveme_mobile/features/beta/tester_mission_copy.dart';

/// Copy for the internal beta release QA checklist — developer diagnostics only.
abstract final class BetaReleaseQaCopy {
  BetaReleaseQaCopy._();

  static const sectionTitle = 'Beta release QA';

  static const manualChecklistTitle = 'Manual tester checklist';

  static const summaryReady = 'Ready for tester build';

  static const summaryNeedsAttention = 'Needs attention before tester build';

  static const statusReady = 'Ready';

  static const statusMissing = 'Missing';

  static const statusCheckManually = 'Check manually';

  static const detailSet = 'Set';

  static const detailMissing = 'Missing';

  static const detailEnabled = 'Enabled';

  static const detailOff = 'Off';

  static const rowBetaMissionFlag = 'Beta mission flag';

  static const rowApiBaseUrlPresent = 'API base URL present';

  static const rowRevenueCatKeyPresent = 'RevenueCat key present';

  static const rowFirstUsePromptAvailable = 'First-use prompt available';

  static const rowTesterMissionAvailable = 'Tester mission available';

  static const rowFirstProofPathAvailable = 'First proof path available';

  static const rowReturnCheckPathAvailable = 'Return check path available';

  static const rowEvidenceTimelineAvailable = 'Evidence timeline available';

  static const rowPrivateReportPreviewAvailable =
      'Private report preview available';

  static const rowProBridgeRouteAvailable = 'Pro bridge route available';

  static const rowActivationDropoffReviewAvailable =
      'Activation drop-off review available';

  static const proBridgeRoute = '/subscription';

  static List<String> get manualChecklistSteps => [
    'Install build',
    'Open app',
    ...TesterMissionCopy.steps,
    'Confirm first proof appears on Patterns',
    'Record a fourth related moment',
    'Answer return check',
    'Open Patterns',
    'Confirm belief, changed card, helpful action, and evidence timeline are visible when eligible',
  ];

  static const coreValueQuestionTitle = 'Core beta value question';

  static const String coreValueQuestion = TesterMissionCopy.feedbackQuestion;

  static const coreValueFeedbackLabel = 'Core value feedback';
}