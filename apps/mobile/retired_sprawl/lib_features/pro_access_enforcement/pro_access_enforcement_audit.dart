import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_copy.dart';
import 'package:archiveme_mobile/features/store_readiness_single_source/store_readiness_single_source.dart';

/// Pro access enforcement audit — clarify what Pro access actually enforces.
abstract final class ProAccessEnforcementAudit {
  ProAccessEnforcementAudit._();

  static const auditItemCount = 8;

  static ProAccessEnforcementAuditResult build(
    ProAccessEnforcementAuditInput input,
  ) {
    final items = _buildItems(input);
    final decision = _resolveDecision(items);
    return ProAccessEnforcementAuditResult(
      decision: decision,
      message: _messageFor(decision),
      items: items,
      earliestBlocker: _earliestBlocker(items),
      hasProductionBlocker: items.any(
        (item) =>
            item.classification ==
            ProAccessEnforcementClassification.productionBlocker,
      ),
      hasDocumentedGaps: items.any(
        (item) =>
            item.classification ==
                ProAccessEnforcementClassification.notEnforcedYet ||
            item.classification ==
                ProAccessEnforcementClassification.acceptableForTestFlight,
      ),
    );
  }

  static ProAccessEnforcementAuditReport report(
    ProAccessEnforcementAuditResult result,
  ) => ProAccessEnforcementAuditReport(
    headline: ProAccessEnforcementAuditCopy.headline,
    body: ProAccessEnforcementAuditCopy.body,
    orderLine: ProAccessEnforcementAuditCopy.orderLine,
    guardrail: ProAccessEnforcementAuditCopy.guardrail,
    result: result,
  );

  static ProAccessEnforcementAuditInput fromStoreReadinessInput(
    StoreReadinessSingleSourceInput input, {
    bool revenueCatLinkedToAccount = false,
    bool localCachePreventsStalePro = true,
    bool serverSideEntitlementCheckPresent = true,
    bool privacyLockIndependentOfPro = true,
  }) => ProAccessEnforcementAuditInput(
    revenueCatConfigured:
        input.revenueCatApiKeyProvided && input.revenueCatConfigured,
    proEntitlementReadable:
        input.proStateCanBeRead &&
        input.proEntitlementConfigured &&
        input.productsLoaded,
    restorePurchasesReachable: input.restorePurchasesReachable,
    restoreNoCrashVerified: input.restoreNoCrashVerified,
    localCachePreventsStalePro: localCachePreventsStalePro,
    entitlementPersistsAfterRestart: input.entitlementPersistsAfterRestart,
    revenueCatLinkedToAccount: revenueCatLinkedToAccount,
    serverSideEntitlementCheckPresent: serverSideEntitlementCheckPresent,
    privacyLockIndependentOfPro: privacyLockIndependentOfPro,
  );

  static List<ProAccessEnforcementAuditItem> _buildItems(
    ProAccessEnforcementAuditInput input,
  ) => [
    _revenueCatEntitlementItem(input),
    _restoreEntitlementItem(input),
    _localCacheItem(input),
    _reinstallBehaviorItem(input),
    _accountIdentityItem(input),
    _deviceSharingItem(input),
    _serverSideEntitlementItem(input),
    _privacyLockSeparateItem(input),
  ];

  static ProAccessEnforcementAuditItem _revenueCatEntitlementItem(
    ProAccessEnforcementAuditInput input,
  ) {
    if (!input.revenueCatConfigured) {
      return _item(
        id: ProAccessEnforcementAuditItemId.revenueCatEntitlement,
        classification:
            ProAccessEnforcementClassification.acceptableForTestFlight,
        detailLabel: ProAccessEnforcementAuditCopy.detailNotApplicableYet,
      );
    }
    if (input.proEntitlementReadable) {
      return _item(
        id: ProAccessEnforcementAuditItemId.revenueCatEntitlement,
        classification: ProAccessEnforcementClassification.enforcedByRevenueCat,
        detailLabel: ProAccessEnforcementAuditCopy.detailVerified,
      );
    }
    return _item(
      id: ProAccessEnforcementAuditItemId.revenueCatEntitlement,
      classification: ProAccessEnforcementClassification.productionBlocker,
      detailLabel: ProAccessEnforcementAuditCopy.detailBroken,
    );
  }

  static ProAccessEnforcementAuditItem _restoreEntitlementItem(
    ProAccessEnforcementAuditInput input,
  ) {
    if (!input.revenueCatConfigured) {
      return _item(
        id: ProAccessEnforcementAuditItemId.restoreEntitlement,
        classification:
            ProAccessEnforcementClassification.acceptableForTestFlight,
        detailLabel: ProAccessEnforcementAuditCopy.detailNotApplicableYet,
      );
    }
    final restoreVerified =
        input.restorePurchasesReachable && input.restoreNoCrashVerified;
    if (restoreVerified) {
      return _item(
        id: ProAccessEnforcementAuditItemId.restoreEntitlement,
        classification: ProAccessEnforcementClassification.enforcedByRevenueCat,
        detailLabel: ProAccessEnforcementAuditCopy.detailVerified,
      );
    }
    return _item(
      id: ProAccessEnforcementAuditItemId.restoreEntitlement,
      classification: ProAccessEnforcementClassification.productionBlocker,
      detailLabel: ProAccessEnforcementAuditCopy.detailBroken,
    );
  }

  static ProAccessEnforcementAuditItem _localCacheItem(
    ProAccessEnforcementAuditInput input,
  ) {
    if (input.localCachePreventsStalePro) {
      return _item(
        id: ProAccessEnforcementAuditItemId.localCache,
        classification: ProAccessEnforcementClassification.enforcedLocally,
        detailLabel: ProAccessEnforcementAuditCopy.detailVerified,
      );
    }
    if (input.revenueCatConfigured) {
      return _item(
        id: ProAccessEnforcementAuditItemId.localCache,
        classification: ProAccessEnforcementClassification.productionBlocker,
        detailLabel: ProAccessEnforcementAuditCopy.detailBroken,
      );
    }
    return _item(
      id: ProAccessEnforcementAuditItemId.localCache,
      classification:
          ProAccessEnforcementClassification.acceptableForTestFlight,
      detailLabel: ProAccessEnforcementAuditCopy.detailDocumentedGap,
    );
  }

  static ProAccessEnforcementAuditItem _reinstallBehaviorItem(
    ProAccessEnforcementAuditInput input,
  ) {
    if (input.entitlementPersistsAfterRestart) {
      return _item(
        id: ProAccessEnforcementAuditItemId.reinstallBehavior,
        classification: ProAccessEnforcementClassification.enforcedLocally,
        detailLabel: ProAccessEnforcementAuditCopy.detailVerified,
      );
    }

    final restoreVerified =
        input.restorePurchasesReachable && input.restoreNoCrashVerified;
    if (input.revenueCatConfigured && restoreVerified) {
      return _item(
        id: ProAccessEnforcementAuditItemId.reinstallBehavior,
        classification: ProAccessEnforcementClassification.enforcedByRevenueCat,
        detailLabel: ProAccessEnforcementAuditCopy.detailRestoreRequired,
      );
    }
    if (input.revenueCatConfigured) {
      return _item(
        id: ProAccessEnforcementAuditItemId.reinstallBehavior,
        classification: ProAccessEnforcementClassification.productionBlocker,
        detailLabel: ProAccessEnforcementAuditCopy.detailBroken,
      );
    }
    return _item(
      id: ProAccessEnforcementAuditItemId.reinstallBehavior,
      classification: ProAccessEnforcementClassification.notEnforcedYet,
      detailLabel: ProAccessEnforcementAuditCopy.detailDocumentedGap,
    );
  }

  static ProAccessEnforcementAuditItem _accountIdentityItem(
    ProAccessEnforcementAuditInput input,
  ) {
    if (input.revenueCatLinkedToAccount) {
      return _item(
        id: ProAccessEnforcementAuditItemId.accountIdentity,
        classification: ProAccessEnforcementClassification.enforcedByRevenueCat,
        detailLabel: ProAccessEnforcementAuditCopy.detailVerified,
      );
    }
    return _item(
      id: ProAccessEnforcementAuditItemId.accountIdentity,
      classification: ProAccessEnforcementClassification.notEnforcedYet,
      detailLabel: ProAccessEnforcementAuditCopy.detailDocumentedGap,
    );
  }

  static ProAccessEnforcementAuditItem _deviceSharingItem(
    ProAccessEnforcementAuditInput input,
  ) => _item(
    id: ProAccessEnforcementAuditItemId.deviceSharing,
    classification: input.deviceSharingPrevented
        ? ProAccessEnforcementClassification.enforcedLocally
        : ProAccessEnforcementClassification.notEnforcedYet,
    detailLabel: input.deviceSharingPrevented
        ? ProAccessEnforcementAuditCopy.detailVerified
        : ProAccessEnforcementAuditCopy.detailDocumentedGap,
  );

  static ProAccessEnforcementAuditItem _serverSideEntitlementItem(
    ProAccessEnforcementAuditInput input,
  ) {
    if (input.serverSideEntitlementCheckPresent) {
      return _item(
        id: ProAccessEnforcementAuditItemId.serverSideEntitlement,
        classification: ProAccessEnforcementClassification.enforcedLocally,
        detailLabel: input.revenueCatConfigured
            ? ProAccessEnforcementAuditCopy.detailDocumentedGap
            : ProAccessEnforcementAuditCopy.detailVerified,
      );
    }
    return _item(
      id: ProAccessEnforcementAuditItemId.serverSideEntitlement,
      classification: ProAccessEnforcementClassification.notEnforcedYet,
      detailLabel: ProAccessEnforcementAuditCopy.detailDocumentedGap,
    );
  }

  static ProAccessEnforcementAuditItem _privacyLockSeparateItem(
    ProAccessEnforcementAuditInput input,
  ) {
    if (input.privacyLockIndependentOfPro) {
      return _item(
        id: ProAccessEnforcementAuditItemId.privacyLockSeparate,
        classification: ProAccessEnforcementClassification.enforcedLocally,
        detailLabel: ProAccessEnforcementAuditCopy.detailVerified,
      );
    }
    return _item(
      id: ProAccessEnforcementAuditItemId.privacyLockSeparate,
      classification: ProAccessEnforcementClassification.productionBlocker,
      detailLabel: ProAccessEnforcementAuditCopy.detailBroken,
    );
  }

  static ProAccessEnforcementAuditItem _item({
    required ProAccessEnforcementAuditItemId id,
    required ProAccessEnforcementClassification classification,
    required String detailLabel,
  }) => ProAccessEnforcementAuditItem(
    id: id,
    label: ProAccessEnforcementAuditCopy.labelFor(id),
    classification: classification,
    classificationLabel: ProAccessEnforcementAuditCopy.classificationLabel(
      classification,
    ),
    detailLabel: detailLabel,
  );

  static ProAccessEnforcementAuditDecision _resolveDecision(
    List<ProAccessEnforcementAuditItem> items,
  ) {
    if (items.any(
      (item) =>
          item.classification ==
          ProAccessEnforcementClassification.productionBlocker,
    )) {
      return ProAccessEnforcementAuditDecision.productionBlocked;
    }

    if (items.any(
      (item) =>
          item.classification ==
              ProAccessEnforcementClassification.notEnforcedYet ||
          item.classification ==
              ProAccessEnforcementClassification.acceptableForTestFlight,
    )) {
      return ProAccessEnforcementAuditDecision.testFlightAcceptable;
    }

    return ProAccessEnforcementAuditDecision.enforcementDocumented;
  }

  static ProAccessEnforcementAuditItemId? _earliestBlocker(
    List<ProAccessEnforcementAuditItem> items,
  ) {
    for (final item in items) {
      if (item.classification ==
          ProAccessEnforcementClassification.productionBlocker) {
        return item.id;
      }
    }
    return null;
  }

  static String _messageFor(ProAccessEnforcementAuditDecision decision) =>
      switch (decision) {
        ProAccessEnforcementAuditDecision.testFlightAcceptable =>
          ProAccessEnforcementAuditCopy.testFlightAcceptableLine,
        ProAccessEnforcementAuditDecision.productionBlocked =>
          ProAccessEnforcementAuditCopy.productionBlockedLine,
        ProAccessEnforcementAuditDecision.enforcementDocumented =>
          ProAccessEnforcementAuditCopy.enforcementDocumentedLine,
      };
}

enum ProAccessEnforcementAuditDecision {
  testFlightAcceptable,
  productionBlocked,
  enforcementDocumented,
}

class ProAccessEnforcementAuditInput {
  const ProAccessEnforcementAuditInput({
    required this.revenueCatConfigured,
    required this.proEntitlementReadable,
    required this.restorePurchasesReachable,
    required this.restoreNoCrashVerified,
    required this.localCachePreventsStalePro,
    required this.entitlementPersistsAfterRestart,
    required this.revenueCatLinkedToAccount,
    required this.serverSideEntitlementCheckPresent,
    required this.privacyLockIndependentOfPro,
    this.deviceSharingPrevented = false,
  });

  final bool revenueCatConfigured;
  final bool proEntitlementReadable;
  final bool restorePurchasesReachable;
  final bool restoreNoCrashVerified;
  final bool localCachePreventsStalePro;
  final bool entitlementPersistsAfterRestart;
  final bool revenueCatLinkedToAccount;
  final bool serverSideEntitlementCheckPresent;
  final bool privacyLockIndependentOfPro;
  final bool deviceSharingPrevented;
}

class ProAccessEnforcementAuditItem {
  const ProAccessEnforcementAuditItem({
    required this.id,
    required this.label,
    required this.classification,
    required this.classificationLabel,
    required this.detailLabel,
  });

  final ProAccessEnforcementAuditItemId id;
  final String label;
  final ProAccessEnforcementClassification classification;
  final String classificationLabel;
  final String detailLabel;
}

class ProAccessEnforcementAuditResult {
  const ProAccessEnforcementAuditResult({
    required this.decision,
    required this.message,
    required this.items,
    required this.earliestBlocker,
    required this.hasProductionBlocker,
    required this.hasDocumentedGaps,
  });

  final ProAccessEnforcementAuditDecision decision;
  final String message;
  final List<ProAccessEnforcementAuditItem> items;
  final ProAccessEnforcementAuditItemId? earliestBlocker;
  final bool hasProductionBlocker;
  final bool hasDocumentedGaps;
}

class ProAccessEnforcementAuditReport {
  const ProAccessEnforcementAuditReport({
    required this.headline,
    required this.body,
    required this.orderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String orderLine;
  final String guardrail;
  final ProAccessEnforcementAuditResult result;
}