import '../landing_continuity/landing_app_continuity_copy.dart';
import '../paywall_alignment/paywall_alignment_copy.dart';

/// Display-only copy for the Pro evidence value bridge — no billing logic.
abstract final class ProEvidenceValueCopy {
  ProEvidenceValueCopy._();

  static const title = PaywallAlignmentCopy.headline;

  static const body = PaywallAlignmentCopy.secondaryReassurance;

  static const cta = 'See what Pro keeps';

  static const secondary = 'Not now';

  static const chatGptDifferentiationLine =
      LandingAppContinuityCopy.chatGptDifferentiation;

  static const evidenceLine =
      'Pro is for keeping the evidence, not getting generic advice.';

  static const comparesMomentsLine =
      'ArchiveMe compares saved moments over time — it is not a chat.';

  static const sheetTitle = 'What Pro keeps';

  static const freeSectionTitle = 'Free';
  static const freeBullets = <String>[
    'First repeat proof',
    'Basic pattern detection',
    'Basic correction',
    'Short archive history',
  ];

  static const proSectionTitle = 'Pro';
  static const proBulletsLive = PaywallAlignmentCopy.benefitBullets;

  static const proExportReportsPlanned = 'Exportable reports (planned)';

  static const sheetFooter =
      'ArchiveMe compares what you saved over time. It is not a chatbot.';

  static const productPromise =
      'ArchiveMe is not a chat. It compares real moments you saved at different times.';

  static const positioningChatGptToday =
      LandingAppContinuityCopy.chatGptDifferentiation;

  static List<String> allVisibleStrings({required bool exportReportsLive}) => [
        title,
        body,
        cta,
        secondary,
        chatGptDifferentiationLine,
        evidenceLine,
        comparesMomentsLine,
        sheetTitle,
        freeSectionTitle,
        ...freeBullets,
        proSectionTitle,
        ...proBulletsForDisplay(exportReportsLive: exportReportsLive),
        sheetFooter,
        productPromise,
        positioningChatGptToday,
      ];

  static List<String> proBulletsForDisplay({required bool exportReportsLive}) {
    if (exportReportsLive) return proBulletsLive;
    return proBulletsLive;
  }
}
