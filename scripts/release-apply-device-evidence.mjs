#!/usr/bin/env node
/**
 * Reads device evidence JSON, runs validators, updates release/focused_beta_status.json gates.
 *
 * Usage:
 *   npm run release:apply-device-evidence
 *   npm run release:apply-device-evidence -- --dry-run
 *   npm run release:apply-device-evidence -- --ios-only
 *   npm run release:apply-device-evidence -- --voiceover-pass --voiceover-evidence release/evidence/voiceover_signoff.md
 */
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  ROOT,
  MANIFEST_PATH,
  evaluateRelease,
  formatBlockerTable,
  loadManifest,
  readGitHead,
  readPubspecIdentity,
  shaMatches,
  writeGeneratedDocs,
} from "./release/focused-beta-core.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  return {
    dryRun: argv.includes("--dry-run"),
    iosOnly: argv.includes("--ios-only"),
    voiceoverPass: argv.includes("--voiceover-pass"),
    voiceoverEvidence: (() => {
      const i = argv.indexOf("--voiceover-evidence");
      return i >= 0 ? argv[i + 1] : null;
    })(),
  };
}

function runValidator(script) {
  try {
    execSync(`npm run ${script}`, { cwd: ROOT, stdio: "pipe", encoding: "utf8" });
    return { ok: true, output: "" };
  } catch (e) {
    return { ok: false, output: e.stdout?.toString() ?? e.stderr?.toString() ?? e.message };
  }
}

function readJson(rel) {
  const p = path.join(ROOT, rel);
  if (!fs.existsSync(p)) return null;
  try {
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch {
    return null;
  }
}

function isoNow() {
  return new Date().toISOString();
}

function waiverExpiry(days = 30) {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString();
}

/** @param {object} manifest @param {string} gateId */
function findGate(manifest, gateId) {
  return manifest.gates.find((g) => g.id === gateId);
}

/** @param {object} gate @param {object} identity @param {object} patch */
function applyPass(gate, identity, patch) {
  gate.status = "pass";
  gate.recordedAt = patch.recordedAt ?? isoNow();
  gate.commitSha = patch.commitSha ?? identity.commitSha;
  gate.buildNumber = patch.buildNumber ?? identity.buildNumber;
  gate.environment = patch.environment ?? "testflight-internal";
  gate.evidencePath = patch.evidencePath ?? gate.evidencePath;
  gate.notes = patch.notes ?? gate.notes;
  gate.waiver = null;
  if (patch.actor) gate.actor = patch.actor;
}

/** @param {object} gate @param {object} identity @param {object} patch */
function applyWaived(gate, identity, patch) {
  gate.status = "waived";
  gate.recordedAt = patch.recordedAt ?? isoNow();
  gate.commitSha = patch.commitSha ?? identity.commitSha;
  gate.buildNumber = patch.buildNumber ?? identity.buildNumber;
  gate.environment = patch.environment ?? "testflight-internal";
  gate.evidencePath = patch.evidencePath ?? gate.evidencePath;
  gate.notes = patch.notes ?? gate.notes;
  gate.waiver = {
    owner: patch.waiverOwner ?? "release-manifest",
    reason: patch.waiverReason ?? gate.notes,
    approvedAt: patch.recordedAt ?? isoNow(),
    expiresAt: patch.waiverExpiresAt ?? waiverExpiry(identity.expirationPolicy?.waiverMaxDays ?? 30),
  };
}

/** @param {object} gate @param {string} reason */
function applyFail(gate, reason) {
  gate.status = "fail";
  gate.notes = reason;
}

function evidenceTimestamp(payload) {
  return payload?.timestamp || payload?.recordedAt || isoNow();
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const manifest = loadManifest();
  const identity = manifest.identity;
  const head = readGitHead(true) ?? identity.commitSha;
  const pubspec = readPubspecIdentity();
  const livePurchases = manifest.capabilities?.storeBilling?.livePurchases === true;
  const changes = [];

  console.log("# Apply device evidence → manifest");
  console.log(
    `${identity.productName} ${identity.semanticVersion}+${identity.buildNumber} @ ${identity.commitSha.slice(0, 7)}`,
  );
  console.log(`livePurchases=${livePurchases} iosOnly=${opts.iosOnly} dryRun=${opts.dryRun}`);
  console.log("");

  // --- ios signing ---
  const iosSigning = runValidator("validate:ios-signing");
  const iosGate = findGate(manifest, "ios_android_build_signing");
  if (iosSigning.ok) {
    const ev = readJson("mobile/evidence/ios_signing_tested.json");
    changes.push("ios signing validator passed");
  } else {
    changes.push(`ios signing validator failed: ${iosSigning.output.split("\n").slice(-3).join(" ")}`);
  }

  // --- android signing ---
  const androidSigning = runValidator("validate:android-signing");
  if (androidSigning.ok) {
    changes.push("android signing validator passed");
  } else if (opts.iosOnly) {
    changes.push("android signing skipped (--ios-only); gate will note iOS-only beta");
  } else {
    changes.push(`android signing validator failed: ${androidSigning.output.split("\n").slice(-3).join(" ")}`);
  }

  if (iosGate) {
    if (iosSigning.ok && (androidSigning.ok || opts.iosOnly)) {
      const ev = readJson("mobile/evidence/ios_signing_tested.json");
      applyPass(iosGate, identity, {
        recordedAt: evidenceTimestamp(ev),
        evidencePath: "mobile/evidence/ios_signing_tested.json",
        notes: opts.iosOnly && !androidSigning.ok
          ? "validate:ios-signing exit 0; Android signing deferred (--ios-only TestFlight internal)."
          : "validate:ios-signing and validate:android-signing exit 0.",
        actor: { type: "manual", name: "npm run release:apply-device-evidence" },
      });
    } else {
      applyFail(
        iosGate,
        !iosSigning.ok
          ? "validate:ios-signing exit 1; update mobile/evidence/ios_signing_tested.json after archive upload."
          : "validate:android-signing exit 1; update mobile/evidence/android_signing_tested.json or pass --ios-only.",
      );
    }
  }

  // --- testflight smoke ---
  const testflight = runValidator("validate:testflight-proof");
  const tfGate = findGate(manifest, "testflight_internal_smoke");
  const tfEv = readJson("mobile/evidence/testflight_tested.json");
  if (testflight.ok && tfGate) {
    applyPass(tfGate, identity, {
      recordedAt: evidenceTimestamp(tfEv),
      evidencePath: "mobile/evidence/testflight_tested.json",
      notes: livePurchases
        ? "validate:testflight-proof exit 0 (full journey incl. purchase/restore)."
        : "validate:testflight-proof exit 0 (smoke-only; livePurchases=false).",
      actor: { type: "manual", name: "npm run validate:testflight-proof" },
    });
    changes.push("testflight smoke gate → pass");
  } else if (tfGate) {
    applyFail(tfGate, "validate:testflight-proof exit 1; complete TestFlight smoke on physical device.");
    changes.push("testflight smoke gate → fail");
  }

  // --- offline sync ---
  const offlineSync = runValidator("validate:offline-sync-production");
  const syncGate = findGate(manifest, "sync_offline_conflict");
  const syncEv = readJson("mobile/evidence/offline_sync_tested.json");
  if (offlineSync.ok && syncGate) {
    const syncNotes = "validate:offline-sync-production exit 0; device evidence matches build/commit.";
    const missingBinding = [];
    if (syncEv?.build_number == null) missingBinding.push("build_number");
    if (!syncEv?.commit_sha) missingBinding.push("commit_sha");
    if (missingBinding.length > 0) {
      applyFail(
        syncGate,
        `offline sync evidence missing ${missingBinding.join(", ")} — export from TestFlight build with SOURCE_COMMIT_SHA.`,
      );
      changes.push(`offline sync gate → fail (missing ${missingBinding.join(", ")})`);
    } else if (syncEv.build_number !== identity.buildNumber) {
      applyFail(syncGate, `offline sync build_number ${syncEv.build_number} != identity ${identity.buildNumber}`);
      changes.push("offline sync gate → fail (build mismatch)");
    } else if (syncEv?.commit_sha && identity.commitSha && !shaMatches(syncEv.commit_sha, identity.commitSha)) {
      applyFail(
        syncGate,
        `offline sync commit_sha ${String(syncEv.commit_sha).slice(0, 7)} != identity ${identity.commitSha.slice(0, 7)}`,
      );
      changes.push("offline sync gate → fail (commit mismatch)");
    } else {
      applyPass(syncGate, identity, {
        recordedAt: evidenceTimestamp(syncEv),
        evidencePath: "mobile/evidence/offline_sync_tested.json",
        notes: syncNotes,
        actor: { type: "manual", name: "npm run validate:offline-sync-production" },
      });
      changes.push("offline sync gate → pass");
    }
  } else if (syncGate) {
    applyFail(
      syncGate,
      "validate:offline-sync-production exit 1; re-run /offline-sync-verify on TestFlight build with SOURCE_COMMIT_SHA.",
    );
    changes.push("offline sync gate → fail");
  }

  // --- purchase / restore ---
  const purchaseGate = findGate(manifest, "purchase_restore");
  if (purchaseGate) {
    if (!livePurchases) {
      applyWaived(purchaseGate, identity, {
        evidencePath: "release/focused_beta_status.json",
        notes: "livePurchases=false; purchase/restore smoke deferred until App Store Connect banking + RevenueCat live.",
        waiverReason:
          "V1CapabilityRegistry storeBilling enabled but livePurchases=false per focused-beta manifest; honest unavailable copy on device.",
      });
      changes.push("purchase_restore gate → waived (livePurchases=false)");
    } else {
      const rc = runValidator("validate:revenuecat-production");
      if (rc.ok && tfEv?.purchase_completed && tfEv?.restore_completed) {
        applyPass(purchaseGate, identity, {
          recordedAt: evidenceTimestamp(tfEv),
          evidencePath: "mobile/evidence/revenuecat_store_tested.json",
          notes: "validate:revenuecat-production exit 0; TestFlight purchase/restore true.",
          actor: { type: "manual", name: "validate:revenuecat-production + TestFlight smoke" },
        });
        changes.push("purchase_restore gate → pass");
      } else {
        applyFail(
          purchaseGate,
          "Live purchases enabled — complete RevenueCat verification and TestFlight purchase/restore smoke.",
        );
        changes.push("purchase_restore gate → fail");
      }
    }
  }

  // --- voiceover manual ---
  const a11yGate = findGate(manifest, "voiceover_talkback_manual");
  if (a11yGate && opts.voiceoverPass) {
    const evidencePath =
      opts.voiceoverEvidence ?? "apps/mobile/docs/ACCESSIBILITY_MANUAL_CHECKLIST.md";
    if (!fs.existsSync(path.join(ROOT, evidencePath))) {
      console.error(`--voiceover-evidence not found: ${evidencePath}`);
      process.exit(1);
    }
    applyPass(a11yGate, identity, {
      recordedAt: isoNow(),
      evidencePath,
      notes: "Manual VoiceOver/TalkBack sign-off recorded via release:apply-device-evidence.",
      actor: { type: "manual", name: "apps/mobile/docs/ACCESSIBILITY_MANUAL_CHECKLIST.md" },
    });
    changes.push("voiceover_talkback_manual gate → pass");
  }

  // Reconcile identity with pubspec/HEAD if aligned
  if (pubspec.buildNumber !== identity.buildNumber) {
    console.warn(
      `Warning: manifest buildNumber ${identity.buildNumber} != pubspec ${pubspec.buildNumber}`,
    );
  }
  if (head && !head.startsWith(identity.commitSha.slice(0, 7)) && identity.commitSha !== head) {
    console.warn(`Warning: manifest commitSha != HEAD (${head.slice(0, 12)})`);
  }

  console.log("## Changes\n");
  for (const c of changes) console.log(`- ${c}`);
  console.log("");

  if (opts.dryRun) {
    console.log("(dry-run — manifest not written)");
    return 0;
  }

  fs.writeFileSync(MANIFEST_PATH, `${JSON.stringify(manifest, null, 2)}\n`);
  writeGeneratedDocs(manifest);

  const result = evaluateRelease(manifest, { headSha: head });
  console.log("## Post-apply verification\n");
  console.log(formatBlockerTable(result.blockers, result.issues));
  if (result.releaseAllowed) {
    console.log("RELEASE ALLOWED");
    return 0;
  }
  console.error(`RELEASE STILL BLOCKED (${result.blockers.length + result.issues.length} issue(s))`);
  return 1;
}

const code = main();
process.exit(code);
