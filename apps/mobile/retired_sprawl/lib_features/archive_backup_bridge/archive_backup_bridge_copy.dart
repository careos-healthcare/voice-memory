import 'package:archiveme_mobile/features/paywall_alignment/paywall_alignment_copy.dart';

/// Display-only copy for the archive preservation bridge — no billing logic.
abstract final class ArchiveBackupBridgeCopy {
  ArchiveBackupBridgeCopy._();

  static const cardTitle = 'Do not lose this archive';

  static const String cardBody = PaywallAlignmentCopy.backupBridgeBody;

  static const plannedProAreas =
      'Backup and multi-device protection are planned Pro areas.';

  static const deviceBackupToday = 'Today, keep your device backed up.';

  static const String proPreservation = PaywallAlignmentCopy.backupProPreservation;

  static const cta = 'How to preserve it';

  static const secondary = 'Not now';

  static const sheetTitle = 'Preserve your archive';

  static const sheetIntro =
      'Your archive may grow more valuable over time. This is guidance only — not a claim that remote backup or sync are turned on.';

  static const sheetLocalBackupLine =
      'You can export a local backup file from Privacy & trust when you want a copy you control.';

  static const sheetSeeProCta = 'See what Pro keeps';

  static List<String> allVisibleStrings() => [
    cardTitle,
    cardBody,
    plannedProAreas,
    deviceBackupToday,
    proPreservation,
    cta,
    secondary,
    sheetTitle,
    sheetIntro,
    sheetLocalBackupLine,
    sheetSeeProCta,
  ];
}