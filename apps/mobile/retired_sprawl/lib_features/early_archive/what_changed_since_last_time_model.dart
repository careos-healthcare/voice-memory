import 'package:archiveme_mobile/features/early_archive/return_check_payoff_model.dart';

/// One row in the compared-evidence section.
class WhatChangedSinceLastTimeEvidenceRow {
  const WhatChangedSinceLastTimeEvidenceRow({required this.label, this.phrase});

  final String label;
  final String? phrase;
}

/// Longitudinal return comparison for Patterns / Archive — not post-save payoff.
class WhatChangedSinceLastTime {
  const WhatChangedSinceLastTime({
    required this.state,
    required this.title,
    required this.summary,
    required this.evidenceLabel,
    required this.evidenceRows,
    required this.footer,
    required this.hasPhrase,
    required this.hasConfirmedRepeat,
  });

  final ReturnCheckPayoffComparisonState state;
  final String title;
  final String summary;
  final String evidenceLabel;
  final List<WhatChangedSinceLastTimeEvidenceRow> evidenceRows;
  final String footer;
  final bool hasPhrase;
  final bool hasConfirmedRepeat;
}