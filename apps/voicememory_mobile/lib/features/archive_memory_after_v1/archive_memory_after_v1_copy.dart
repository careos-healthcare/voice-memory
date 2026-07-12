/// Archive memory after V1 copy — future enhancement after V1 proof.
abstract final class ArchiveMemoryAfterV1Copy {
  ArchiveMemoryAfterV1Copy._();

  static const headline = 'Archive memory after V1 gate';

  static const body =
      'Keep archive memory expansion after V1 proof. Classification and documentation only.';

  static const positioning =
      'Archive memory stays a future enhancement — proof-trail support, not storage headline.';

  static const orderLine =
      'Rules: future enhancement only, not first five minutes, not primary Pro promise, '
      'proof trail not storage, no new live V1 UI.';

  static const guardrail =
      'Archive memory after V1 gate classifies future archive memory expansion only. '
      'Archive memory is a future enhancement — not part of first five minutes, not the primary Pro promise. '
      'Must support proof trail, not storage. No new live V1 UI.';

  static const archiveMemoryFrozenLine =
      'Keep archive memory expansion frozen until paid-intent beta proof is complete.';

  static const futureArchiveMemoryDocumentedLine =
      'Beta proof complete. Document archive memory as future enhancement only — proof trail, not storage, no new live V1 UI.';

  static const detailPass = 'Pass';
  static const detailFail = 'Fail';

  static const detailArchiveMemoryFrozen = 'Archive memory frozen before beta proof';
  static const detailFutureArchiveMemoryDocumented =
      'Future archive memory documented only';

  static String ruleLabelFor(ArchiveMemoryAfterV1RuleId id) => switch (id) {
        ArchiveMemoryAfterV1RuleId.futureEnhancementOnly => 'Future enhancement only',
        ArchiveMemoryAfterV1RuleId.notPartOfFirstFiveMinutes =>
          'Not part of first five minutes',
        ArchiveMemoryAfterV1RuleId.notPrimaryProPromise => 'Not primary Pro promise',
        ArchiveMemoryAfterV1RuleId.supportsProofTrailNotStorage =>
          'Supports proof trail, not storage',
        ArchiveMemoryAfterV1RuleId.noNewLiveV1Ui => 'No new live V1 UI',
      };

  static String messageFor(ArchiveMemoryAfterV1GateDecision decision) =>
      switch (decision) {
        ArchiveMemoryAfterV1GateDecision.archiveMemoryFrozen =>
          archiveMemoryFrozenLine,
        ArchiveMemoryAfterV1GateDecision.futureArchiveMemoryDocumented =>
          futureArchiveMemoryDocumentedLine,
      };

  static String recommendationFor(ArchiveMemoryAfterV1GateDecision decision) =>
      switch (decision) {
        ArchiveMemoryAfterV1GateDecision.archiveMemoryFrozen =>
          'Keep archive memory out of first five minutes and off the primary Pro promise until beta proof completes.',
        ArchiveMemoryAfterV1GateDecision.futureArchiveMemoryDocumented =>
          'Document archive memory as future enhancement only. Keep proof trail as the frame, not storage.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield orderLine;
    yield guardrail;
    yield archiveMemoryFrozenLine;
    yield futureArchiveMemoryDocumentedLine;
    yield detailPass;
    yield detailFail;
    yield detailArchiveMemoryFrozen;
    yield detailFutureArchiveMemoryDocumented;
    for (final id in ArchiveMemoryAfterV1RuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in ArchiveMemoryAfterV1GateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum ArchiveMemoryAfterV1RuleId {
  futureEnhancementOnly,
  notPartOfFirstFiveMinutes,
  notPrimaryProPromise,
  supportsProofTrailNotStorage,
  noNewLiveV1Ui,
}

enum ArchiveMemoryAfterV1RuleStatus {
  pass,
  fail,
}

enum ArchiveMemoryAfterV1GateDecision {
  archiveMemoryFrozen,
  futureArchiveMemoryDocumented,
}
