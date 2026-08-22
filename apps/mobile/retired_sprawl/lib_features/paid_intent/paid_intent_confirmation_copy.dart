import 'package:archiveme_mobile/features/paid_intent/paid_intent_confirmation_models.dart';

/// Copy for local paid intent confirmation — no payment CTAs.
abstract final class PaidIntentConfirmationCopy {
  PaidIntentConfirmationCopy._();

  static const title = 'Would you pay to keep this archive?';
  static const body =
      'ArchiveMe is still in beta. No payment is taken. This helps decide whether the archive is valuable enough to keep building.';
  static const question =
      'If ArchiveMe kept showing what changed in your yes pattern over time, would you pay for it?';

  static const optionYes999 = 'Yes — £9.99/month';
  static const optionMaybe = 'Maybe — if it keeps improving';
  static const optionNotYet = 'Not yet';
  static const optionNo = 'No';

  static const saveAnswerCta = 'Save answer';
  static const skipForNowCta = 'Skip for now';

  static const noPaymentNote =
      'No payment is taken. No subscription is started.';

  static const dashboardSectionTitle = 'Paid intent';
  static const dashboardNotEnoughSignal = 'Not enough value signal yet';
  static const dashboardAnsweredPrefix = 'Paid intent answer';

  static const supportSectionTitle = 'Paid intent check';
  static const supportSectionBody =
      'After you reach real value in the capacity loop, you can answer a local willingness-to-pay question. No payment is taken.';
  static const supportOpenDashboardCta = 'Open capacity beta signals';

  static const paymentSignalStrong = 'Strong paid intent';
  static const paymentSignalSoft = 'Soft paid intent';
  static const paymentSignalNotYet = 'Not yet';
  static const paymentSignalNo = 'No';
  static const paymentSignalSkipped = 'Skipped';
  static const paymentSignalNotAnswered = 'Not answered yet';

  static String labelForResponseId(String responseId) => switch (responseId) {
    PaidIntentConfirmationResponseIds.yes999 => optionYes999,
    PaidIntentConfirmationResponseIds.maybe => optionMaybe,
    PaidIntentConfirmationResponseIds.notYet => optionNotYet,
    PaidIntentConfirmationResponseIds.no => optionNo,
    _ => paymentSignalNotAnswered,
  };

  static String paymentSignalLabelForRecord(
    PaidIntentConfirmationRecord? record,
  ) {
    if (record == null || !record.isComplete) {
      return paymentSignalNotAnswered;
    }
    if (record.isSkipped) return paymentSignalSkipped;
    return switch (record.responseId) {
      PaidIntentConfirmationResponseIds.yes999 => paymentSignalStrong,
      PaidIntentConfirmationResponseIds.maybe => paymentSignalSoft,
      PaidIntentConfirmationResponseIds.notYet => paymentSignalNotYet,
      PaidIntentConfirmationResponseIds.no => paymentSignalNo,
      _ => paymentSignalNotAnswered,
    };
  }

  static String answeredSummaryLine(String responseId) =>
      '$dashboardAnsweredPrefix: ${labelForResponseId(responseId)}';

  static List<String> responseOptionLabels() => [
    optionYes999,
    optionMaybe,
    optionNotYet,
    optionNo,
  ];

  static String responseIdForLabel(String label) => switch (label) {
    optionYes999 => PaidIntentConfirmationResponseIds.yes999,
    optionMaybe => PaidIntentConfirmationResponseIds.maybe,
    optionNotYet => PaidIntentConfirmationResponseIds.notYet,
    optionNo => PaidIntentConfirmationResponseIds.no,
    _ => '',
  };

  static List<String> allVisibleStrings() => [
    title,
    body,
    question,
    optionYes999,
    optionMaybe,
    optionNotYet,
    optionNo,
    saveAnswerCta,
    skipForNowCta,
    noPaymentNote,
    dashboardSectionTitle,
    dashboardNotEnoughSignal,
    dashboardAnsweredPrefix,
    supportSectionTitle,
    supportSectionBody,
    supportOpenDashboardCta,
    paymentSignalStrong,
    paymentSignalSoft,
    paymentSignalNotYet,
    paymentSignalNo,
    paymentSignalSkipped,
    paymentSignalNotAnswered,
  ];
}