/// What a piece of archive evidence *is* — the explicit separation
/// between raw user material, derived patterns, and generated text.
///
/// ArchiveMe preserves exact evidence: raw entries are the source of
/// truth, extracted facts and user-marked details reference them,
/// patterns reference supporting evidence, and generated
/// interpretations are temporary views that can never become evidence
/// themselves.
enum ArchiveEvidenceType {
  /// A concrete user-recorded detail (or structured check-in signal).
  fact,

  /// Repeated evidence across entries — always backed by supporting
  /// evidence ids internally, never by paraphrased text.
  pattern,

  /// Generated/cautious summary text. A view, not evidence.
  interpretation,

  /// A detail the user explicitly marked "Keep exact details".
  userMarkedDetail,

  /// User chose Preserve original — source wording stays evidence.
  preservedOriginal,

  /// Evidence linked by an explicit shared thread/context marker.
  thread,

  /// An entry being kept separate (treat-as-new) — no claim authority.
  fresh,
}

extension ArchiveEvidenceTypeId on ArchiveEvidenceType {
  /// Stable analytics-safe id — never user text.
  String get id => switch (this) {
    ArchiveEvidenceType.fact => 'fact',
    ArchiveEvidenceType.pattern => 'pattern',
    ArchiveEvidenceType.interpretation => 'interpretation',
    ArchiveEvidenceType.userMarkedDetail => 'user_marked_detail',
    ArchiveEvidenceType.preservedOriginal => 'preserved_original',
    ArchiveEvidenceType.thread => 'thread',
    ArchiveEvidenceType.fresh => 'fresh',
  };

  /// Consumer-facing label — evidence framing, never identity claims.
  String get label => switch (this) {
    ArchiveEvidenceType.fact => 'Exact detail',
    ArchiveEvidenceType.pattern => 'Repeated evidence',
    ArchiveEvidenceType.interpretation => 'Generated note',
    ArchiveEvidenceType.userMarkedDetail => 'Marked exact by you',
    ArchiveEvidenceType.preservedOriginal => 'Original preserved',
    ArchiveEvidenceType.thread => 'Shared thread',
    ArchiveEvidenceType.fresh => 'Fresh entry',
  };

  /// Whether evidence of this type may act as source-of-truth support
  /// for a memory claim. Generated interpretation never can — it is a
  /// temporary view over evidence, not evidence. Fresh entries opted
  /// out of claims entirely.
  bool get canBeSourceOfTruth => switch (this) {
    ArchiveEvidenceType.fact => true,
    ArchiveEvidenceType.pattern => true,
    ArchiveEvidenceType.userMarkedDetail => true,
    ArchiveEvidenceType.preservedOriginal => true,
    ArchiveEvidenceType.thread => true,
    ArchiveEvidenceType.interpretation => false,
    ArchiveEvidenceType.fresh => false,
  };
}