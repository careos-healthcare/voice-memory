import '../single_launch_checklist/single_launch_checklist.dart';
import '../sync_expectation_safety/sync_expectation_safety_guard.dart';
import 'cross_device_continuity_future_copy.dart';

/// Cross device continuity future gate — future only until technically proven.
abstract final class CrossDeviceContinuityFutureGate {
  CrossDeviceContinuityFutureGate._();

  static const ruleCount = 5;
  static const prereqCount = 5;

  static const canonicalRuleOrder = [
    CrossDeviceContinuityFutureRuleId.futureOnly,
    CrossDeviceContinuityFutureRuleId.noCloudBackupPromise,
    CrossDeviceContinuityFutureRuleId.noAccessEverywherePromise,
    CrossDeviceContinuityFutureRuleId.noNeverLoseArchivePromise,
    CrossDeviceContinuityFutureRuleId.technicalProofBeforeLaunch,
  ];

  static const canonicalPrereqOrder = [
    CrossDeviceContinuityFuturePrereqId.accountIdentityProof,
    CrossDeviceContinuityFuturePrereqId.restoreProof,
    CrossDeviceContinuityFuturePrereqId.backupProof,
    CrossDeviceContinuityFuturePrereqId.privacyProof,
    CrossDeviceContinuityFuturePrereqId.migrationProof,
  ];

  static const cloudBackupViolationMarkers = [
    'cloud backup keeps',
    'automatic cloud backup',
    'your archive is backed up to the cloud',
    'cloud backup included',
  ];

  static const accessEverywhereViolationMarkers = [
    'access everywhere',
    'access your archive anywhere',
    'available on every device',
  ];

  static const neverLoseArchiveViolationMarkers = [
    'never lose your archive',
    'you will never lose your archive',
    'archive is never lost',
  ];

  static CrossDeviceContinuityFutureGateResult build(
    CrossDeviceContinuityFutureGateInput input,
  ) {
    final rules = _buildRules(input);
    final prereqs = _buildPrereqs(input);
    final rulesPass = rules.every(
      (rule) => rule.status == CrossDeviceContinuityFutureRuleStatus.pass,
    );
    final technicalProofComplete = prereqs.every(
      (prereq) => prereq.status == CrossDeviceContinuityFuturePrereqStatus.pass,
    );
    final decision = rulesPass && technicalProofComplete
        ? CrossDeviceContinuityFutureGateDecision.futureContinuityDocumented
        : CrossDeviceContinuityFutureGateDecision.continuityFrozen;
    return CrossDeviceContinuityFutureGateResult(
      decision: decision,
      message: CrossDeviceContinuityFutureCopy.messageFor(decision),
      recommendation: CrossDeviceContinuityFutureCopy.recommendationFor(decision),
      positioning: CrossDeviceContinuityFutureCopy.positioning,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      prereqs: prereqs,
      prereqOrder: canonicalPrereqOrder,
      technicalProofComplete: technicalProofComplete,
      v1SurfacingBlocked: decision ==
          CrossDeviceContinuityFutureGateDecision.continuityFrozen,
      cloudPromiseBlocked: true,
      accessEverywherePromiseBlocked: true,
      neverLoseArchivePromiseBlocked: true,
      earliestPrereqGap: prereqs
          .where(
            (prereq) =>
                prereq.status != CrossDeviceContinuityFuturePrereqStatus.pass,
          )
          .map((prereq) => prereq.id)
          .firstOrNull,
      earliestRuleFailure: rules
          .where(
            (rule) => rule.status == CrossDeviceContinuityFutureRuleStatus.fail,
          )
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static CrossDeviceContinuityFutureGateReport report(
    CrossDeviceContinuityFutureGateResult result,
  ) =>
      CrossDeviceContinuityFutureGateReport(
        headline: CrossDeviceContinuityFutureCopy.headline,
        body: CrossDeviceContinuityFutureCopy.body,
        positioning: CrossDeviceContinuityFutureCopy.positioning,
        orderLine: CrossDeviceContinuityFutureCopy.orderLine,
        prereqOrderLine: CrossDeviceContinuityFutureCopy.prereqOrderLine,
        guardrail: CrossDeviceContinuityFutureCopy.guardrail,
        result: result,
      );

  static CrossDeviceContinuityFutureGateInput composeInput({
    bool? accountIdentityProof,
    bool? restoreProof,
    bool? backupProof,
    bool? privacyProof,
    bool? migrationProof,
    bool? v1ContinuitySurfacingRequested,
    SingleLaunchChecklistInput? launchChecklist,
  }) =>
      CrossDeviceContinuityFutureGateInput(
        accountIdentityProof: accountIdentityProof ??
            launchChecklist?.productionApiWorks,
        restoreProof: restoreProof ?? launchChecklist?.restoreWorks,
        backupProof: backupProof,
        privacyProof: privacyProof ?? launchChecklist?.supportPrivacyTermsWork,
        migrationProof: migrationProof,
        v1ContinuitySurfacingRequested: v1ContinuitySurfacingRequested,
      );

  static CrossDeviceContinuityFutureGateInput fromRepoSignals({
    required String crossDeviceContinuityFutureDocSource,
    required String gateCopySource,
    required String syncExpectationSafetyGuardSource,
    bool? accountIdentityProof,
    bool? restoreProof,
    bool? backupProof,
    bool? privacyProof,
    bool? migrationProof,
    bool? v1ContinuitySurfacingRequested,
  }) =>
      CrossDeviceContinuityFutureGateInput(
        accountIdentityProof: accountIdentityProof,
        restoreProof: restoreProof,
        backupProof: backupProof,
        privacyProof: privacyProof,
        migrationProof: migrationProof,
        v1ContinuitySurfacingRequested: v1ContinuitySurfacingRequested,
        docListsRules: detectDocListsRules(crossDeviceContinuityFutureDocSource),
        guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
        syncExpectationSafetyAligned: detectSyncExpectationSafetyAligned(
          syncExpectationSafetyGuardSource,
        ),
      );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'future only',
      'no cloud backup promise',
      'no access everywhere promise',
      'never lose your archive',
      'migration proof',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('future only') &&
        lower.contains('no cloud backup promise') &&
        lower.contains('no access everywhere promise') &&
        lower.contains('no never lose your archive promise') &&
        lower.contains('migration proof');
  }

  static bool detectSyncExpectationSafetyAligned(
    String syncExpectationSafetyGuardSource,
  ) {
    final lower = syncExpectationSafetyGuardSource.toLowerCase();
    return lower.contains('cloud backup') &&
        lower.contains('access everywhere') &&
        lower.contains('never lose your archive');
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesCloudBackupPromise(copy) &&
      !_violatesAccessEverywherePromise(copy) &&
      !_violatesNeverLoseArchivePromise(copy) &&
      SyncExpectationSafetyGuard.passes(copy);

  static List<CrossDeviceContinuityFutureRule> _buildRules(
    CrossDeviceContinuityFutureGateInput input,
  ) {
    final copyBundle = [
      CrossDeviceContinuityFutureCopy.positioning,
      CrossDeviceContinuityFutureCopy.guardrail,
      CrossDeviceContinuityFutureCopy.body,
    ].join(' ');
    final guardrailLower = CrossDeviceContinuityFutureCopy.guardrail.toLowerCase();
    final technicalProofComplete = canonicalPrereqOrder.every((id) {
      final value = _prereqValueFor(input, id);
      return value == true;
    });
    return [
      _rule(
        id: CrossDeviceContinuityFutureRuleId.futureOnly,
        passes: guardrailLower.contains('future only') &&
            (!(input.v1ContinuitySurfacingRequested ?? false) ||
                technicalProofComplete),
      ),
      _rule(
        id: CrossDeviceContinuityFutureRuleId.noCloudBackupPromise,
        passes: evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('no cloud backup promise'),
      ),
      _rule(
        id: CrossDeviceContinuityFutureRuleId.noAccessEverywherePromise,
        passes: evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('no access everywhere promise'),
      ),
      _rule(
        id: CrossDeviceContinuityFutureRuleId.noNeverLoseArchivePromise,
        passes: evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('no never lose your archive promise'),
      ),
      _rule(
        id: CrossDeviceContinuityFutureRuleId.technicalProofBeforeLaunch,
        passes: guardrailLower.contains('migration proof') &&
            technicalProofComplete,
      ),
    ];
  }

  static List<CrossDeviceContinuityFuturePrereq> _buildPrereqs(
    CrossDeviceContinuityFutureGateInput input,
  ) =>
      canonicalPrereqOrder
          .map(
            (id) => _prereq(
              id: id,
              value: _prereqValueFor(input, id),
            ),
          )
          .toList();

  static bool? _prereqValueFor(
    CrossDeviceContinuityFutureGateInput input,
    CrossDeviceContinuityFuturePrereqId id,
  ) =>
      switch (id) {
        CrossDeviceContinuityFuturePrereqId.accountIdentityProof =>
          input.accountIdentityProof,
        CrossDeviceContinuityFuturePrereqId.restoreProof => input.restoreProof,
        CrossDeviceContinuityFuturePrereqId.backupProof => input.backupProof,
        CrossDeviceContinuityFuturePrereqId.privacyProof => input.privacyProof,
        CrossDeviceContinuityFuturePrereqId.migrationProof =>
          input.migrationProof,
      };

  static bool _violatesCloudBackupPromise(String copy) =>
      cloudBackupViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesAccessEverywherePromise(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in accessEverywhereViolationMarkers) {
      var index = 0;
      while (true) {
        index = lower.indexOf(marker, index);
        if (index < 0) break;
        if (!_markerInProhibitionContext(lower, index)) return true;
        index += marker.length;
      }
    }
    return false;
  }

  static bool _violatesNeverLoseArchivePromise(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in neverLoseArchiveViolationMarkers) {
      var index = 0;
      while (true) {
        index = lower.indexOf(marker, index);
        if (index < 0) break;
        if (!_markerInProhibitionContext(lower, index)) return true;
        index += marker.length;
      }
    }
    return false;
  }

  static bool _markerInProhibitionContext(String lower, int markerStart) {
    final prefix = lower.substring(0, markerStart);
    const prohibitionMarkers = ['avoid ', 'without ', 'never ', 'no ', 'not '];
    for (final marker in prohibitionMarkers) {
      final index = prefix.lastIndexOf(marker);
      if (index < 0) continue;
      final between = prefix.substring(index + marker.length);
      if (!between.contains('. ')) return true;
    }
    return false;
  }

  static CrossDeviceContinuityFuturePrereqStatus _statusFor(bool? value) =>
      switch (value) {
        true => CrossDeviceContinuityFuturePrereqStatus.pass,
        false => CrossDeviceContinuityFuturePrereqStatus.fail,
        null => CrossDeviceContinuityFuturePrereqStatus.pending,
      };

  static CrossDeviceContinuityFuturePrereq _prereq({
    required CrossDeviceContinuityFuturePrereqId id,
    required bool? value,
  }) {
    final status = _statusFor(value);
    return CrossDeviceContinuityFuturePrereq(
      id: id,
      label: CrossDeviceContinuityFutureCopy.prereqLabelFor(id),
      status: status,
      detailLabel: switch (status) {
        CrossDeviceContinuityFuturePrereqStatus.pass =>
          CrossDeviceContinuityFutureCopy.detailPass,
        CrossDeviceContinuityFuturePrereqStatus.pending =>
          CrossDeviceContinuityFutureCopy.detailPending,
        CrossDeviceContinuityFuturePrereqStatus.fail =>
          CrossDeviceContinuityFutureCopy.detailFail,
      },
    );
  }

  static CrossDeviceContinuityFutureRule _rule({
    required CrossDeviceContinuityFutureRuleId id,
    required bool passes,
  }) =>
      CrossDeviceContinuityFutureRule(
        id: id,
        label: CrossDeviceContinuityFutureCopy.ruleLabelFor(id),
        status: passes
            ? CrossDeviceContinuityFutureRuleStatus.pass
            : CrossDeviceContinuityFutureRuleStatus.fail,
        detailLabel: passes
            ? CrossDeviceContinuityFutureCopy.detailPass
            : CrossDeviceContinuityFutureCopy.detailFail,
      );
}

class CrossDeviceContinuityFutureGateInput {
  const CrossDeviceContinuityFutureGateInput({
    this.accountIdentityProof,
    this.restoreProof,
    this.backupProof,
    this.privacyProof,
    this.migrationProof,
    this.v1ContinuitySurfacingRequested,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
    this.syncExpectationSafetyAligned = true,
  });

  final bool? accountIdentityProof;
  final bool? restoreProof;
  final bool? backupProof;
  final bool? privacyProof;
  final bool? migrationProof;
  final bool? v1ContinuitySurfacingRequested;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
  final bool syncExpectationSafetyAligned;
}

class CrossDeviceContinuityFutureRule {
  const CrossDeviceContinuityFutureRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final CrossDeviceContinuityFutureRuleId id;
  final String label;
  final CrossDeviceContinuityFutureRuleStatus status;
  final String detailLabel;
}

class CrossDeviceContinuityFuturePrereq {
  const CrossDeviceContinuityFuturePrereq({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final CrossDeviceContinuityFuturePrereqId id;
  final String label;
  final CrossDeviceContinuityFuturePrereqStatus status;
  final String detailLabel;
}

class CrossDeviceContinuityFutureGateResult {
  const CrossDeviceContinuityFutureGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.prereqs,
    required this.prereqOrder,
    required this.technicalProofComplete,
    required this.v1SurfacingBlocked,
    required this.cloudPromiseBlocked,
    required this.accessEverywherePromiseBlocked,
    required this.neverLoseArchivePromiseBlocked,
    required this.earliestPrereqGap,
    required this.earliestRuleFailure,
  });

  final CrossDeviceContinuityFutureGateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final List<CrossDeviceContinuityFutureRule> rules;
  final List<CrossDeviceContinuityFutureRuleId> ruleOrder;
  final bool rulesPass;
  final List<CrossDeviceContinuityFuturePrereq> prereqs;
  final List<CrossDeviceContinuityFuturePrereqId> prereqOrder;
  final bool technicalProofComplete;
  final bool v1SurfacingBlocked;
  final bool cloudPromiseBlocked;
  final bool accessEverywherePromiseBlocked;
  final bool neverLoseArchivePromiseBlocked;
  final CrossDeviceContinuityFuturePrereqId? earliestPrereqGap;
  final CrossDeviceContinuityFutureRuleId? earliestRuleFailure;
}

class CrossDeviceContinuityFutureGateReport {
  const CrossDeviceContinuityFutureGateReport({
    required this.headline,
    required this.body,
    required this.positioning,
    required this.orderLine,
    required this.prereqOrderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String positioning;
  final String orderLine;
  final String prereqOrderLine;
  final String guardrail;
  final CrossDeviceContinuityFutureGateResult result;
}
