/// Display-only copy for the Pro evidence value bridge — no billing logic.
abstract final class ProEvidenceValueCopy {
  ProEvidenceValueCopy._();

  static const title = 'Keep the longer story';

  static const body =
      'Free shows the first proof. Pro keeps more of the pattern history, change timeline, private reports, and older evidence.';

  static const cta = 'See what Pro keeps';

  static const secondary = 'Not now';

  static const chatGptDifferentiationLine =
      'ChatGPT answers one conversation. ArchiveMe compares what you saved over time.';

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
  static const proBulletsLive = <String>[
    'Longer archive memory',
    'More pattern history',
    'Change timeline',
    'Private reports',
    'Older evidence',
    'More review history',
    'Exportable reports',
  ];

  static const proExportReportsPlanned = 'Exportable reports (planned)';

  static const sheetFooter =
      'ArchiveMe is not trying to answer better than ChatGPT. It remembers differently.';

  static const productPromise =
      'ArchiveMe is not a chat. It compares real moments you saved at different times.';

  static const positioningChatGptToday =
      'ChatGPT helps you think today. ArchiveMe shows what keeps repeating across your life.';

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
    return [
      ...proBulletsLive.where((b) => b != 'Exportable reports'),
      proExportReportsPlanned,
    ];
  }
}
