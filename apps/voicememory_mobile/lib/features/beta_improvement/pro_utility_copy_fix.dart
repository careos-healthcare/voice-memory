/// Gated Pro utility previews — narrow expansion, not full feature build.
abstract final class ProUtilityCopyFix {
  ProUtilityCopyFix._();

  static const headline = 'Keep more of the trail.';

  static const subheadline =
      'When the first proof matters, Pro helps you keep the older evidence, history, and summaries around it.';

  static const historyTitle = 'Older proof history';
  static const historyBody =
      'See how a repeat changed across more saved moments.';

  static const exportTitle = 'Export your archive';
  static const exportBody =
      'Keep a copy of your saved moments and proof trail.';

  static const exportPlannedBody = 'Export is planned for Pro utility.';

  static const privateReportTitle = 'Private report preview';
  static const privateReportBody =
      'See what returned, what changed, what softened, and what to watch next.';

  static const proofBridge =
      'You asked for more history. That is what Pro is for.';

  static const previewHonesty =
      'Preview only until your archive has enough evidence.';

  static const unavailableHonesty =
      'Purchases are not available right now.';

  static const notMoreAiLine =
      'Not more AI — more of your own evidence kept over time.';

  static const previewLabel = 'Pro utility preview';
  static const plannedSuffix = '(planned preview — not live yet)';

  /// Legacy aliases kept for existing preview wiring.
  static const historyPreview = historyTitle;
  static const exportPreview = exportTitle;
  static const reportPreview = privateReportTitle;

  static const List<String> bannedWords = [
    'therapy',
    'diagnosis',
    'treatment',
    'trauma',
    'healing',
    'mental health',
    'ai coach',
    'chatbot',
    'breakthrough',
    'unlimited coaching',
    'better answers',
    'ask archive',
    'loop packs',
    'annual plan',
    'cloud backup',
    'cross-device',
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield subheadline;
    yield historyTitle;
    yield historyBody;
    yield exportTitle;
    yield exportBody;
    yield exportPlannedBody;
    yield privateReportTitle;
    yield privateReportBody;
    yield proofBridge;
    yield previewHonesty;
    yield unavailableHonesty;
    yield notMoreAiLine;
    yield previewLabel;
    yield plannedSuffix;
  }
}
