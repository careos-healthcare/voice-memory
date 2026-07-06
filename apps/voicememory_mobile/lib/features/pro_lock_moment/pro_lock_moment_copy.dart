/// Display-only copy for the Pro lock moment — no billing logic.
abstract final class ProLockMomentCopy {
  ProLockMomentCopy._();

  static const title = 'This is the first proof.';

  static const body =
      'ArchiveMe found something by comparing moments you saved at different times.';

  static const paidReason =
      'Pro keeps the longer story — more history, private reports, and evidence over time.';

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
