import fs from "node:fs";
import path from "node:path";

import type {
  ReleaseEvidenceId,
  ReleaseEvidenceRecord,
  StructuralEvidenceSignal,
} from "@/types/mobile-production-readiness";

export const RELEASE_EVIDENCE_IDS: readonly ReleaseEvidenceId[] = [
  "testflight_uploaded",
  "play_internal_uploaded",
  "ios_purchase_tested",
  "android_purchase_tested",
  "push_notifications_tested",
  "background_recording_tested",
  "offline_mode_tested",
  "sync_recovery_tested",
  "revenuecat_store_tested",
  "stripe_checkout_tested",
  "restore_purchases_tested",
  "ios_signing_release",
  "android_signing_release",
] as const;

const EVIDENCE_DIR = path.join(process.cwd(), "mobile", "evidence");

function repoRoot(): string {
  return process.cwd();
}

function flutterRoot(): string {
  return path.join(repoRoot(), "apps", "archiveme_mobile");
}

function readText(rel: string): string {
  const full = path.join(repoRoot(), rel);
  if (!fs.existsSync(full)) return "";
  return fs.readFileSync(full, "utf8");
}

function parseEvidenceFile(filePath: string): ReleaseEvidenceRecord | null {
  try {
    const raw = fs.readFileSync(filePath, "utf8");
    const parsed = JSON.parse(raw) as Partial<ReleaseEvidenceRecord>;
    if (!parsed.id || typeof parsed.passed !== "boolean") return null;
    if (!RELEASE_EVIDENCE_IDS.includes(parsed.id as ReleaseEvidenceId)) return null;
    return {
      id: parsed.id as ReleaseEvidenceId,
      passed: parsed.passed,
      recordedAt: parsed.recordedAt ?? new Date().toISOString(),
      source: parsed.source ?? "file",
      note: parsed.note ?? "",
    };
  } catch {
    return null;
  }
}

/** Load committed evidence JSON from mobile/evidence/*.json — no manual checkboxes. */
export function readReleaseEvidenceRecords(
  evidenceDir = EVIDENCE_DIR,
): ReleaseEvidenceRecord[] {
  if (!fs.existsSync(evidenceDir)) return [];

  const records: ReleaseEvidenceRecord[] = [];
  for (const ent of fs.readdirSync(evidenceDir, { withFileTypes: true })) {
    if (!ent.isFile() || !ent.name.endsWith(".json")) continue;
    const record = parseEvidenceFile(path.join(evidenceDir, ent.name));
    if (record) records.push(record);
  }

  const envMap: Partial<Record<ReleaseEvidenceId, string>> = {
    testflight_uploaded: process.env.MOBILE_EVIDENCE_TESTFLIGHT,
    play_internal_uploaded: process.env.MOBILE_EVIDENCE_PLAY_INTERNAL,
    ios_purchase_tested: process.env.MOBILE_EVIDENCE_IOS_PURCHASE,
    android_purchase_tested: process.env.MOBILE_EVIDENCE_ANDROID_PURCHASE,
    push_notifications_tested: process.env.MOBILE_EVIDENCE_PUSH,
    background_recording_tested: process.env.MOBILE_EVIDENCE_BACKGROUND_RECORDING,
    offline_mode_tested: process.env.MOBILE_EVIDENCE_OFFLINE,
    sync_recovery_tested: process.env.MOBILE_EVIDENCE_SYNC_RECOVERY,
    revenuecat_store_tested: process.env.MOBILE_EVIDENCE_REVENUECAT,
    stripe_checkout_tested: process.env.MOBILE_EVIDENCE_STRIPE,
    restore_purchases_tested: process.env.MOBILE_EVIDENCE_RESTORE_PURCHASES,
    ios_signing_release: process.env.MOBILE_EVIDENCE_IOS_SIGNING,
    android_signing_release: process.env.MOBILE_EVIDENCE_ANDROID_SIGNING,
  };

  for (const [id, raw] of Object.entries(envMap)) {
    if (!raw) continue;
    const passed = raw === "1" || raw.toLowerCase() === "true" || raw.toLowerCase() === "pass";
    records.push({
      id: id as ReleaseEvidenceId,
      passed,
      recordedAt: new Date().toISOString(),
      source: "env",
      note: `MOBILE_EVIDENCE_${id}`,
    });
  }

  const byId = new Map<ReleaseEvidenceId, ReleaseEvidenceRecord>();
  for (const row of records) {
    const existing = byId.get(row.id);
    if (!existing || row.source === "file") {
      byId.set(row.id, row);
    }
  }
  return [...byId.values()];
}

/** Repo structure signals — FAILING when integration is provably absent. */
export function collectStructuralEvidenceSignals(): StructuralEvidenceSignal[] {
  const signals: StructuralEvidenceSignal[] = [];
  const pubspec = readText("apps/mobile/pubspec.yaml");
  const iosChecklist = readText("apps/mobile/docs/IOS_RELEASE_CHECKLIST.md");
  const androidGradle = readText("apps/mobile/android/app/build.gradle.kts");
  const paymentStack = readText("lib/entitlement/payment-stack.ts");

  const fcmIntegrated = pubspec.includes("firebase_messaging");
  signals.push({
    id: "push_not_integrated",
    passed: fcmIntegrated,
    note: fcmIntegrated
      ? "firebase_messaging integrated — native_push_verification.json evidence required (FCM)"
      : "firebase_messaging missing — production push not integrated",
  });

  signals.push({
    id: "background_not_integrated",
    passed: false,
    note: "Recording uses foreground `record` package only — no background audio entitlement evidenced",
  });

  signals.push({
    id: "offline_partial",
    passed: false,
    note:
      readText("apps/mobile/lib/storage/journal_store.dart").includes("class JournalStore")
        ? "Local journal store exists; offline_mode_tested evidence still required for store claim"
        : "No local journal persistence found",
  });

  signals.push({
    id: "sync_path_present",
    passed: readText("apps/mobile/lib/services/sync_service.dart").includes("syncNow"),
    note: "SyncService present — sync_recovery_tested evidence required for recovery proof",
  });

  signals.push({
    id: "sync_recovery_not_evidenced",
    passed: false,
    note: "No sync_recovery_tested evidence on file",
  });

  signals.push({
    id: "testflight_not_uploaded",
    passed: false,
    note: "No testflight_uploaded evidence on file",
  });

  signals.push({
    id: "play_internal_not_uploaded",
    passed: false,
    note: "No play_internal_uploaded evidence on file",
  });

  signals.push({
    id: "ios_signing_not_evidenced",
    passed: false,
    note: "No ios_signing_release evidence on file",
  });

  signals.push({
    id: "android_signing_not_evidenced",
    passed: false,
    note: "No android_signing_release evidence on file",
  });

  const rcIntegrated =
    pubspec.includes("purchases_flutter") &&
    readText("apps/mobile/lib/billing/revenuecat_service.dart").includes(
      "RevenueCatService",
    );

  signals.push({
    id: "revenuecat_absent",
    passed: rcIntegrated,
    note: rcIntegrated
      ? "RevenueCat integrated — revenuecat_store_tested evidence still required for PASSING"
      : "RevenueCat not integrated",
  });

  signals.push({
    id: "restore_absent",
    passed:
      rcIntegrated &&
      readText("apps/mobile/lib/screens/restore_purchases_screen.dart").includes(
        "restoreNative",
      ),
    note: rcIntegrated
      ? "Restore screen present — restore_purchases_tested evidence still required"
      : "No restore purchases flow in Flutter app",
  });

  signals.push({
    id: "stripe_browser_only",
    passed: !readText("apps/mobile/lib/screens/pricing_screen.dart").includes(
      "launchUrl",
    ),
    note: rcIntegrated
      ? "Browser Stripe removed from mobile pricing flow"
      : "Mobile may still use browser checkout — integrate RevenueCat",
  });

  signals.push({
    id: "stripe_checkout_not_evidenced",
    passed: false,
    note: "No stripe_checkout_tested evidence on file",
  });

  const iosWorkspace = fs.existsSync(
    path.join(flutterRoot(), "ios", "Runner.xcworkspace"),
  );
  signals.push({
    id: "ios_project_present",
    passed: iosWorkspace,
    note: iosWorkspace
      ? "Runner.xcworkspace present — ios_signing_release evidence required for PASSING"
      : "iOS workspace missing",
  });

  signals.push({
    id: "android_release_debug_signing",
    passed: !androidGradle.includes('signingConfigs.getByName("debug")'),
    note: androidGradle.includes('signingConfigs.getByName("debug")')
      ? "Android release build still uses debug signing"
      : "Release signing config present — android_signing_release evidence still required",
  });

  if (iosChecklist.includes("No push entitlement for v1")) {
    signals.push({
      id: "ios_push_disabled_v1",
      passed: false,
      note: "Documented: no push entitlement for v1",
    });
  }

  return signals;
}

export function evidenceDirPath(): string {
  return EVIDENCE_DIR;
}
