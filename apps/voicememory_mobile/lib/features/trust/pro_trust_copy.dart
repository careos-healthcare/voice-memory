/// Pro trust + proof loop — compile-time consumer copy for test sweeps.
library;

/// Stable stage ids for analytics — never user text.
abstract class ProTrustStage {
  ProTrustStage._();

  static const String keepExact = 'keep_exact';
  static const String pinned = 'pinned';
  static const String actionItem = 'action_item';
  static const String pack = 'pack';
  static const String thread = 'thread';
  static const String seriousUse = 'serious_use';
  static const String proClarity = 'pro_clarity';
  static const String ahaProofShare = 'aha_proof_share';
}

abstract class ProTrustCopy {
  ProTrustCopy._();

  // A. Private trust receipt.
  static const String receiptTitle = 'Saved privately';
  static const String receiptBody =
      'You control whether this connects to your archive, stays separate, '
      'or gets exported.';
  static const String receiptReviewCta = 'Review controls';
  static const String receiptNotNow = 'Not now';

  // B. Pro value clarity.
  static const String proTitle = 'Keep your archive useful over time';
  static const String proBody =
      'Unlock deeper history, saved evidence, and continuity as your '
      'archive grows.';
  static const String proBulletFind = 'Find important entries faster';
  static const String proBulletExport = 'Export what matters';
  static const String proBulletContext =
      'Keep archive context useful over time';
  static const String proCta = 'See Pro';
  static const String proSecondary = 'Not now';

  // C. Aha proof share.
  static const String shareTitle = 'Share the moment';
  static const String shareBody =
      'Share a private summary without your entry text.';
  static const String shareTextTemplate =
      'My archive noticed something I came back to again.\n\nRecorded with ArchiveMe.';
  static const String shareCopyCta = 'Copy share text';
  static const String shareCta = 'Share';
  static const String shareNotNow = 'Not now';

  static const List<String> all = [
    receiptTitle,
    receiptBody,
    receiptReviewCta,
    receiptNotNow,
    proTitle,
    proBody,
    proBulletFind,
    proBulletExport,
    proBulletContext,
    proCta,
    proSecondary,
    shareTitle,
    shareBody,
    shareTextTemplate,
    shareCopyCta,
    shareCta,
    shareNotNow,
  ];
}
