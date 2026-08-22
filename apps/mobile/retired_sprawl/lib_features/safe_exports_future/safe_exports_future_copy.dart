/// Safe exports future copy — future paid expansion, not launch promise.
abstract final class SafeExportsFutureCopy {
  SafeExportsFutureCopy._();

  static const headline = 'Safe exports future gate';

  static const body =
      'Prepare exports as future paid expansion without making them a launch promise. '
      'Classification and documentation only.';

  static const positioning =
      'Exports stay future paid expansion — never the launch promise or primary Pro headline.';

  static const orderLine =
      'Export types: proof trail PDF, markdown archive, local backup, what changed monthly '
      'report, evidence trail export.';

  static const prereqOrderLine =
      'Prerequisites: export tests pass and paid-intent beta complete.';

  static const guardrail =
      'Safe exports future gate classifies future export types only. Not the primary Pro promise. Never leak private raw text without explicit user export action. Tested before marketing. No new export UI for V1.';

  static const exportsFrozenLine =
      'Exports frozen until export tests pass and paid-intent beta proof are complete.';

  static const futurePaidExpansionDocumentedLine =
      'Export tests and beta proof complete. Document exports as future paid expansion only — '
      'not in V1 UI or launch promise.';

  static const detailPass = 'Pass';
  static const detailPending = 'Pending';
  static const detailFail = 'Fail';

  static const detailBlockedBeforeExportProof = 'Blocked before export proof';
  static const detailFuturePaidExpansionDocumented =
      'Future paid expansion documented only';

  static String labelFor(SafeExportFutureId id) => switch (id) {
    SafeExportFutureId.proofTrailPdf => 'Proof trail PDF',
    SafeExportFutureId.markdownArchive => 'Markdown archive',
    SafeExportFutureId.localBackup => 'Local backup',
    SafeExportFutureId.whatChangedMonthlyReport =>
      'What changed monthly report',
    SafeExportFutureId.evidenceTrailExport => 'Evidence trail export',
  };

  static String positioningFor(SafeExportFutureId id) => switch (id) {
    SafeExportFutureId.proofTrailPdf =>
      'Future PDF export of proof trail summaries — explicit user action only.',
    SafeExportFutureId.markdownArchive =>
      'Future markdown archive export — explicit user action only.',
    SafeExportFutureId.localBackup =>
      'Future on-device backup export — explicit user action only.',
    SafeExportFutureId.whatChangedMonthlyReport =>
      'Future monthly what-changed report export — explicit user action only.',
    SafeExportFutureId.evidenceTrailExport =>
      'Future evidence trail export — explicit user action only.',
  };

  static String prereqLabelFor(SafeExportFuturePrereqId id) => switch (id) {
    SafeExportFuturePrereqId.exportTestsPass => 'Export tests pass',
    SafeExportFuturePrereqId.paidIntentBetaComplete =>
      'Paid-intent beta complete',
  };

  static String ruleLabelFor(SafeExportsFutureRuleId id) => switch (id) {
    SafeExportsFutureRuleId.notPrimaryProPromise => 'Not primary Pro promise',
    SafeExportsFutureRuleId.noPrivateRawTextLeak =>
      'No private raw text leak without explicit export',
    SafeExportsFutureRuleId.testedBeforeMarketing => 'Tested before marketing',
    SafeExportsFutureRuleId.noNewExportUiForV1 => 'No new export UI for V1',
  };

  static String messageFor(SafeExportsFutureGateDecision decision) =>
      switch (decision) {
        SafeExportsFutureGateDecision.exportsFrozen => exportsFrozenLine,
        SafeExportsFutureGateDecision.futurePaidExpansionDocumented =>
          futurePaidExpansionDocumentedLine,
      };

  static String recommendationFor(
    SafeExportsFutureGateDecision decision,
  ) => switch (decision) {
    SafeExportsFutureGateDecision.exportsFrozen =>
      'Finish export tests and paid-intent beta before using exports in paid expansion planning.',
    SafeExportsFutureGateDecision.futurePaidExpansionDocumented =>
      'Document exports as future paid expansion only. Keep proof trail as the primary promise. No V1 export UI.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield orderLine;
    yield prereqOrderLine;
    yield guardrail;
    yield exportsFrozenLine;
    yield futurePaidExpansionDocumentedLine;
    yield detailPass;
    yield detailPending;
    yield detailFail;
    yield detailBlockedBeforeExportProof;
    yield detailFuturePaidExpansionDocumented;
    for (final id in SafeExportFutureId.values) {
      yield labelFor(id);
      yield positioningFor(id);
    }
    for (final id in SafeExportFuturePrereqId.values) {
      yield prereqLabelFor(id);
    }
    for (final id in SafeExportsFutureRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in SafeExportsFutureGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum SafeExportFutureId {
  proofTrailPdf,
  markdownArchive,
  localBackup,
  whatChangedMonthlyReport,
  evidenceTrailExport,
}

enum SafeExportFuturePrereqId { exportTestsPass, paidIntentBetaComplete }

enum SafeExportFuturePrereqStatus { pass, pending, fail }

enum SafeExportFutureStatus {
  blockedBeforeExportProof,
  futurePaidExpansionDocumented,
}

enum SafeExportsFutureRuleId {
  notPrimaryProPromise,
  noPrivateRawTextLeak,
  testedBeforeMarketing,
  noNewExportUiForV1,
}

enum SafeExportsFutureRuleStatus { pass, fail }

enum SafeExportsFutureGateDecision {
  exportsFrozen,
  futurePaidExpansionDocumented,
}