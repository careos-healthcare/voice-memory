/// Local funnel counters for the activation drop-off review — counts only.
class ActivationDropoffCounters {
  const ActivationDropoffCounters({
    this.appOpened = 0,
    this.firstUsePromptSeen = 0,
    this.firstMomentSaved = 0,
    this.returnedAfterFirstMoment = 0,
    this.secondMomentSaved = 0,
    this.firstProofReached = 0,
    this.returnedAfterFirstProof = 0,
    this.fourthMomentSaved = 0,
    this.returnCheckAnswered = 0,
    this.proBoundarySeen = 0,
    this.proTapped = 0,
  });

  final int appOpened;
  final int firstUsePromptSeen;
  final int firstMomentSaved;
  final int returnedAfterFirstMoment;
  final int secondMomentSaved;
  final int firstProofReached;
  final int returnedAfterFirstProof;
  final int fourthMomentSaved;
  final int returnCheckAnswered;
  final int proBoundarySeen;
  final int proTapped;
}

enum ActivationDropoffRowId {
  appOpened,
  firstUsePromptSeen,
  firstMomentSaved,
  returnedAfterFirstMoment,
  secondMomentSaved,
  firstProofReached,
  returnedAfterFirstProof,
  fourthMomentSaved,
  returnCheckAnswered,
  proBoundarySeen,
  proTapped,
}

enum ActivationDropoffRowStatus {
  notReached,
  started,
  reached;

  String get label => switch (this) {
    ActivationDropoffRowStatus.notReached => 'Not reached',
    ActivationDropoffRowStatus.started => 'Started',
    ActivationDropoffRowStatus.reached => 'Reached',
  };
}

class ActivationDropoffRow {
  const ActivationDropoffRow({
    required this.id,
    required this.label,
    required this.count,
    required this.status,
  });

  final ActivationDropoffRowId id;
  final String label;
  final int count;
  final ActivationDropoffRowStatus status;
}

class ActivationDropoffReview {
  const ActivationDropoffReview({
    required this.title,
    required this.rows,
    required this.bottleneckLabel,
    required this.bottleneckSummary,
    required this.activationLoopComplete,
  });

  final String title;
  final List<ActivationDropoffRow> rows;
  final String bottleneckLabel;
  final String bottleneckSummary;
  final bool activationLoopComplete;
}