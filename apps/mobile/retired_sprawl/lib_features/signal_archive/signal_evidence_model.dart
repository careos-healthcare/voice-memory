/// How a journal moment relates to a saved signal.
enum SignalEvidenceRelation { supports, mightContradict, unclear }

extension SignalEvidenceRelationLabels on SignalEvidenceRelation {
  String get label {
    switch (this) {
      case SignalEvidenceRelation.supports:
        return 'Supports';
      case SignalEvidenceRelation.mightContradict:
        return 'Might contradict';
      case SignalEvidenceRelation.unclear:
        return 'Unclear';
    }
  }
}

/// One moment in a signal's evidence trail — excerpt only, not full transcript.
class SignalEvidenceItem {
  const SignalEvidenceItem({
    required this.entryId,
    required this.date,
    required this.excerpt,
    required this.tag,
    required this.relation,
  });

  final String entryId;
  final DateTime date;
  final String excerpt;
  final String tag;
  final SignalEvidenceRelation relation;
}

/// Evidence trail for the current selected signal.
class SignalEvidenceTrail {
  const SignalEvidenceTrail({
    required this.items,
    required this.clarityPrompt,
    required this.nextEvidencePrompt,
    required this.needsMoreEvidence,
  });

  final List<SignalEvidenceItem> items;
  final String clarityPrompt;
  final String nextEvidencePrompt;
  final bool needsMoreEvidence;

  List<SignalEvidenceItem> get supportingItems => items
      .where((i) => i.relation == SignalEvidenceRelation.supports)
      .toList();

  List<SignalEvidenceItem> get contradictingItems => items
      .where((i) => i.relation == SignalEvidenceRelation.mightContradict)
      .toList();
}