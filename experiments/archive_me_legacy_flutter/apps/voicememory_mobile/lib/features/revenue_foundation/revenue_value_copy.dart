import '../landing_continuity/landing_app_continuity_copy.dart';
import '../paywall_alignment/paywall_alignment_copy.dart';

/// Canonical revenue value copy — display only, no billing logic.
abstract final class RevenueValueCopy {
  RevenueValueCopy._();

  static const positioningHeadline =
      LandingAppContinuityCopy.chatGptDifferentiation;
  static const positioningSubhead = 'ArchiveMe remembers differently.';

  static const memoryJob =
      'It compares moments saved over time and shows what returned, changed, softened, disappeared, or helped.';

  static const paidReasonHeadline = PaywallAlignmentCopy.headline;

  static const paidReasonBody = PaywallAlignmentCopy.body;

  static const paidReasonEvidenceLine =
      'Pro is for keeping the evidence, not getting generic advice.';

  static const chatGptDifferentiationLine =
      LandingAppContinuityCopy.chatGptDifferentiation;

  static const comparesMomentsLine =
      'ArchiveMe compares saved moments over time — it is not a chat.';

  static const longTermHistoryHeadline = 'Longer archive history';

  static const longTermHistoryBody =
      'Pro keeps more of your saved moments available as patterns grow across weeks — what returned, changed, softened, or got quieter.';

  static const privateReportHeadline = 'Private reports';

  static const privateReportBody =
      'Private reports are planned — coming after Pro proof. Not part of the V1 purchase promise.';

  static const exportHeadline = 'Export a copy you control';

  static const exportBodyLive =
      'Take a private report or recap out of the app when you choose.';

  static const exportBodyPlanned =
      'Exports are planned — coming after Pro proof. Pro is still for keeping the longer proof trail.';

  static const safeSharingHeadline =
      'Talk about patterns with someone you trust';

  static const safeSharingBody =
      'Private sharing may help you talk about patterns with someone you trust.';

  static const safeSharingDisclaimer = 'ArchiveMe is not a healthcare product.';

  static const safeSharingChoice = 'Only share what you choose.';

  static const safeSharingFutureNote =
      'Read-only sharing with someone you trust is a future direction — not available in the app yet.';

  static const syncFutureNote =
      'Cloud backup and multi-device sync are future directions — not live today.';

  static const bannedMedicalTerms = <String>[
    'therapy',
    'diagnosis',
    'treatment',
    'mental health care',
    'medical advice',
    'clinical',
    'therapist replacement',
  ];

  static const bannedLiveOverpromises = <String>[
    'automatic cloud backup',
    'sync across all devices',
    'share with your therapist automatically',
  ];

  static List<String> allConsumerStrings({
    required bool exportReportsLive,
    required bool safeSharingLive,
  }) => [
    positioningHeadline,
    positioningSubhead,
    memoryJob,
    paidReasonHeadline,
    paidReasonBody,
    paidReasonEvidenceLine,
    chatGptDifferentiationLine,
    comparesMomentsLine,
    longTermHistoryHeadline,
    longTermHistoryBody,
    privateReportHeadline,
    privateReportBody,
    exportHeadline,
    exportBodyForDisplay(exportReportsLive: exportReportsLive),
    if (!safeSharingLive) safeSharingFutureNote,
    safeSharingHeadline,
    safeSharingBody,
    safeSharingDisclaimer,
    safeSharingChoice,
    syncFutureNote,
  ];

  static String exportBodyForDisplay({required bool exportReportsLive}) =>
      exportReportsLive ? exportBodyLive : exportBodyPlanned;

  static String exportLabelForDisplay({required bool exportReportsLive}) =>
      exportReportsLive ? 'Exportable reports' : 'Exportable reports (planned)';
}
