import 'pro_preview_model.dart';

/// Generic Pro preview rows — no fake locked evidence or journal text.
abstract final class ProPreviewCopy {
  ProPreviewCopy._();

  static const title = 'What Pro keeps';
  static const body =
      'Your first proof is free. Pro keeps the longer proof trail over time.';
  static const cta = 'See Pro';
  static const secondary = 'Not now';

  static const fullPatternTimeline = 'Longer proof trail';
  static const whatReturned = 'What returned';
  static const whatChanged = 'What changed';
  static const whatYouCorrected = 'What you corrected';
  static const currentVsFading = 'Current vs fading signals';
  static const monthlyPrivateReport = 'What faded';
  static const backupContinuity = 'Trail continuity over weeks';

  static const bannedFakeClaims = <String>[
    'limited time',
    'only today',
    'testimonial',
    'users say',
    '5-star',
    'locked',
  ];

  static const bannedMedicalTerms = <String>[
    'therapy',
    'diagnosis',
    'treatment',
    'clinical',
  ];

  static List<ProPreviewRow> previewRows() => const [
        ProPreviewRow(id: ProPreviewRowId.fullPatternTimeline, label: fullPatternTimeline),
        ProPreviewRow(id: ProPreviewRowId.whatReturned, label: whatReturned),
        ProPreviewRow(id: ProPreviewRowId.whatChanged, label: whatChanged),
        ProPreviewRow(id: ProPreviewRowId.whatYouCorrected, label: whatYouCorrected),
        ProPreviewRow(id: ProPreviewRowId.currentVsFading, label: currentVsFading),
        ProPreviewRow(id: ProPreviewRowId.monthlyPrivateReport, label: monthlyPrivateReport),
        ProPreviewRow(id: ProPreviewRowId.backupContinuity, label: backupContinuity),
      ];

  static List<String> allDisplayedStrings() => [
        title,
        body,
        cta,
        secondary,
        for (final row in previewRows()) row.label,
      ];
}
