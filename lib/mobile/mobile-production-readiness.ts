import {
  collectStructuralEvidenceSignals,
  readReleaseEvidenceRecords,
} from "@/lib/mobile/release-evidence";
import { buildNativePushReadinessReport } from "@/lib/mobile/native-push-verification";
import {
  buildRevenueCatProductionReport,
  isRevenueCatProductionPassing,
  readRevenueCatStoreEvidence,
  REVENUECAT_STORE_EVIDENCE_PATH,
} from "@/lib/mobile/revenuecat-production-verification";
import {
  buildRestoreProductionReport,
  isRestoreProductionPassing,
  readRestorePurchasesEvidence,
  RESTORE_PURCHASES_EVIDENCE_PATH,
} from "@/lib/mobile/restore-production-verification";
import type {
  MobileProductionReadinessReport,
  ReadinessPillarScore,
  ReleaseEvidenceId,
  StoreReadinessItem,
  StoreReadinessItemId,
  StoreReadinessStatus,
} from "@/types/mobile-production-readiness";

type ItemSpec = {
  id: StoreReadinessItemId;
  label: string;
  requiredEvidence: ReleaseEvidenceId[];
  structuralFailIds?: string[];
};

const STORE_ITEMS: ItemSpec[] = [
  {
    id: "push_notifications",
    label: "Push notifications",
    requiredEvidence: [],
    structuralFailIds: [],
  },
  {
    id: "background_recording",
    label: "Background recording",
    requiredEvidence: ["background_recording_tested"],
    structuralFailIds: ["background_not_integrated"],
  },
  {
    id: "offline_mode",
    label: "Offline mode",
    requiredEvidence: ["offline_mode_tested"],
    structuralFailIds: ["offline_partial"],
  },
  {
    id: "sync_recovery",
    label: "Sync recovery",
    requiredEvidence: ["sync_recovery_tested"],
    structuralFailIds: ["sync_recovery_not_evidenced"],
  },
  {
    id: "revenuecat",
    label: "RevenueCat",
    requiredEvidence: ["revenuecat_store_tested"],
    structuralFailIds: ["revenuecat_absent"],
  },
  {
    id: "stripe",
    label: "Stripe",
    requiredEvidence: ["stripe_checkout_tested"],
    structuralFailIds: ["stripe_checkout_not_evidenced"],
  },
  {
    id: "restore_purchases",
    label: "Restore purchases",
    requiredEvidence: ["restore_purchases_tested"],
    structuralFailIds: ["restore_absent"],
  },
  {
    id: "ios_signing",
    label: "iOS signing",
    requiredEvidence: ["ios_signing_release"],
    structuralFailIds: ["ios_signing_not_evidenced"],
  },
  {
    id: "android_signing",
    label: "Android signing",
    requiredEvidence: ["android_signing_release"],
    structuralFailIds: ["android_release_debug_signing", "android_signing_not_evidenced"],
  },
  {
    id: "testflight",
    label: "TestFlight",
    requiredEvidence: ["testflight_uploaded"],
    structuralFailIds: ["testflight_not_uploaded"],
  },
  {
    id: "play_store",
    label: "Play Store",
    requiredEvidence: ["play_internal_uploaded"],
    structuralFailIds: ["play_internal_not_uploaded"],
  },
];

function resolveItemStatus(
  spec: ItemSpec,
  evidenceById: Map<ReleaseEvidenceId, { passed: boolean; note: string }>,
  structuralById: Map<string, { passed: boolean; note: string }>,
): StoreReadinessItem {
  const evidenceNotes: string[] = [];
  const required = spec.requiredEvidence;

  const passingEvidence = required.filter((id) => evidenceById.get(id)?.passed === true);
  const failingEvidence = required.filter((id) => {
    const row = evidenceById.get(id);
    return row && !row.passed;
  });

  for (const id of required) {
    const row = evidenceById.get(id);
    if (row) {
      evidenceNotes.push(`${id}: ${row.passed ? "pass" : "fail"} — ${row.note}`);
    }
  }

  for (const sid of spec.structuralFailIds ?? []) {
    const sig = structuralById.get(sid);
    if (sig) evidenceNotes.push(`structural:${sid} — ${sig.note}`);
  }

  let status: StoreReadinessStatus;

  const structuralFails = (spec.structuralFailIds ?? []).filter(
    (sid) => structuralById.get(sid)?.passed === false,
  );

  if (passingEvidence.length === required.length && required.length > 0) {
    status = "PASSING";
  } else if (failingEvidence.length > 0 || structuralFails.length > 0) {
    status = "FAILING";
  } else if (passingEvidence.length > 0) {
    status = "FAILING";
  } else if (evidenceNotes.length === 0) {
    status = "UNKNOWN";
  } else {
    status = "FAILING";
  }

  return {
    id: spec.id,
    label: spec.label,
    status,
    requiredEvidence: required,
    evidenceNotes,
  };
}

function resolveRevenueCatItem(
  structuralById: Map<string, { passed: boolean; note: string }>,
): StoreReadinessItem {
  const report = buildRevenueCatProductionReport();
  const evidence = readRevenueCatStoreEvidence();
  const notes: string[] = [
    "Evidence-only — no structural pass without revenuecat_store_tested.json",
    `File: ${REVENUECAT_STORE_EVIDENCE_PATH}`,
    report.summary,
  ];
  if (evidence) {
    notes.push(
      `purchase_completed=${evidence.purchase_completed} entitlement_received=${evidence.entitlement_received} restore_completed=${evidence.restore_completed}`,
    );
  }
  if (report.missingRequirements.length) {
    notes.push(`Missing: ${report.missingRequirements.join(", ")}`);
  }
  const structural = structuralById.get("revenuecat_absent");
  if (structural) notes.push(`structural:revenuecat_absent — ${structural.note}`);

  let status: StoreReadinessStatus = report.status;
  if (status === "PASSING" && !isRevenueCatProductionPassing(evidence)) {
    status = "FAILING";
  }

  return {
    id: "revenuecat",
    label: "RevenueCat",
    status,
    requiredEvidence: ["revenuecat_store_tested"],
    evidenceNotes: notes,
  };
}

function resolveRestorePurchasesItem(
  structuralById: Map<string, { passed: boolean; note: string }>,
): StoreReadinessItem {
  const report = buildRestoreProductionReport();
  const evidence = readRestorePurchasesEvidence();
  const notes: string[] = [
    "Evidence-only — success=true after purchase → delete → reinstall → restore",
    `File: ${RESTORE_PURCHASES_EVIDENCE_PATH}`,
    report.summary,
  ];
  if (evidence) {
    notes.push(
      `success=${evidence.success} platform=${evidence.platform || "—"} device=${evidence.device || "—"}`,
    );
  }
  if (report.missingRequirements.length) {
    notes.push(`Missing: ${report.missingRequirements.join(", ")}`);
  }
  const structural = structuralById.get("restore_absent");
  if (structural) notes.push(`structural:restore_absent — ${structural.note}`);

  let status: StoreReadinessStatus = report.status;
  if (status === "PASSING" && !isRestoreProductionPassing(evidence)) {
    status = "FAILING";
  }

  return {
    id: "restore_purchases",
    label: "Restore purchases",
    status,
    requiredEvidence: ["restore_purchases_tested"],
    evidenceNotes: notes,
  };
}

function resolveNativePushNotificationsItem(): StoreReadinessItem {
  const native = buildNativePushReadinessReport();
  const notes = [
    "Production FCM only — validate:push-production (no local notifications).",
    "Web push verification does not count — physical iOS and Android only.",
    `iOS: ${native.ios.status} · Android: ${native.android.status}`,
    `Evidence: mobile/evidence/native_push_verification.json`,
  ];
  if (native.ios.missingSteps.length) {
    notes.push(`iOS missing: ${native.ios.missingSteps.join(", ")}`);
  }
  if (native.android.missingSteps.length) {
    notes.push(`Android missing: ${native.android.missingSteps.join(", ")}`);
  }
  if (native.ios.destinationGaps.length) {
    notes.push(`iOS destinations: ${native.ios.destinationGaps.join(", ")}`);
  }
  if (native.android.destinationGaps.length) {
    notes.push(`Android destinations: ${native.android.destinationGaps.join(", ")}`);
  }

  let status: StoreReadinessStatus = "FAILING";
  if (!native.evidence) {
    status = "UNKNOWN";
  } else if (native.ios.status === "PASSING" && native.android.status === "PASSING") {
    status = "PASSING";
  } else if (native.ios.status === "UNKNOWN" || native.android.status === "UNKNOWN") {
    status = "UNKNOWN";
  }

  return {
    id: "push_notifications",
    label: "Push notifications",
    status,
    requiredEvidence: [],
    evidenceNotes: notes,
  };
}

function pillarFromItems(
  label: string,
  items: StoreReadinessItem[],
): ReadinessPillarScore {
  const total = items.length;
  const passing = items.filter((i) => i.status === "PASSING").length;
  const unknown = items.filter((i) => i.status === "UNKNOWN").length;
  const failing = items.filter((i) => i.status === "FAILING").length;

  let status: StoreReadinessStatus = "FAILING";
  if (unknown > 0) status = "UNKNOWN";
  else if (passing === total) status = "PASSING";
  else if (passing > 0) status = "FAILING";

  const summary =
    unknown > 0
      ? `${unknown} item(s) lack evidence`
      : `${passing}/${total} passing · ${failing} failing`;

  return { label, status, passing, total, summary };
}

export function buildMobileProductionReadinessReport(): MobileProductionReadinessReport {
  const generatedAt = new Date().toISOString();
  const evidence = readReleaseEvidenceRecords();
  const structural = collectStructuralEvidenceSignals();

  const evidenceById = new Map(
    evidence.map((e) => [e.id, { passed: e.passed, note: e.note }]),
  );
  const structuralById = new Map(
    structural.map((s) => [s.id, { passed: s.passed, note: s.note }]),
  );

  const items = STORE_ITEMS.map((spec) => {
    if (spec.id === "push_notifications") return resolveNativePushNotificationsItem();
    if (spec.id === "revenuecat") return resolveRevenueCatItem(structuralById);
    if (spec.id === "restore_purchases") return resolveRestorePurchasesItem(structuralById);
    return resolveItemStatus(spec, evidenceById, structuralById);
  });

  const unknownCount = items.filter((i) => i.status === "UNKNOWN").length;
  const failingCount = items.filter((i) => i.status === "FAILING").length;
  const passingCount = items.filter((i) => i.status === "PASSING").length;

  const productIds: StoreReadinessItemId[] = [
    "push_notifications",
    "background_recording",
    "offline_mode",
    "sync_recovery",
  ];
  const storeIds: StoreReadinessItemId[] = [
    "revenuecat",
    "stripe",
    "restore_purchases",
    "ios_signing",
    "android_signing",
  ];
  const distributionIds: StoreReadinessItemId[] = ["testflight", "play_store"];

  const productReadiness = pillarFromItems(
    "Product Readiness",
    items.filter((i) => productIds.includes(i.id)),
  );
  const storeReadiness = pillarFromItems(
    "Store Readiness",
    items.filter((i) => storeIds.includes(i.id)),
  );
  const distributionReadiness = pillarFromItems(
    "Distribution Readiness",
    items.filter((i) => distributionIds.includes(i.id)),
  );

  const lines = [
    `Generated ${generatedAt}`,
    `Checklist: ${passingCount} passing · ${failingCount} failing · ${unknownCount} unknown`,
    `Evidence files: ${evidence.length} · Structural signals: ${structural.length}`,
    "",
    "Product Readiness — " + productReadiness.summary,
    "Store Readiness — " + storeReadiness.summary,
    "Distribution Readiness — " + distributionReadiness.summary,
    "",
    ...items.map(
      (i) =>
        `${i.label}: ${i.status} (evidence: ${i.requiredEvidence.join(", ")})`,
    ),
  ];

  return {
    generatedAt,
    items,
    unknownCount,
    failingCount,
    passingCount,
    productReadiness,
    storeReadiness,
    distributionReadiness,
    lines,
  };
}
