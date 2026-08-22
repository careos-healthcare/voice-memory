import 'package:archiveme_mobile/features/paywall_alignment/paywall_alignment_copy.dart';

/// Display-only copy for the Pro lock moment — no billing logic.
abstract final class ProLockMomentCopy {
  ProLockMomentCopy._();

  static const title = 'This is the first proof.';

  static const body =
      'ArchiveMe found something by comparing moments you saved at different times.';

  static const String paidReason = PaywallAlignmentCopy.lockMomentPaidReason;

  static const chatDifferentiation =
      'This is not a chat answer. It is a pattern found across your saved moments.';

  static const cta = 'See what Pro keeps';

  static const secondary = 'Not now';

  static const sheetTitle = 'First proof';

  static List<String> allVisibleStrings() => [
    title,
    body,
    paidReason,
    chatDifferentiation,
    cta,
    secondary,
    sheetTitle,
  ];
}