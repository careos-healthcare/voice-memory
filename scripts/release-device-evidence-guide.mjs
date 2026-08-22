#!/usr/bin/env node
/**
 * Prints TestFlight + offline-sync device evidence steps and runs repo preflight.
 */
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  ROOT,
  evaluateRelease,
  formatBlockerTable,
  loadManifest,
  readGitHead,
  readPubspecIdentity,
} from "./release/focused-beta-core.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function heading(text) {
  console.log(`\n## ${text}\n`);
}

function step(n, text) {
  console.log(`${n}. ${text}`);
}

function main() {
  const manifest = loadManifest();
  const identity = manifest.identity;
  const pubspec = readPubspecIdentity();
  const head = readGitHead(true) ?? "unknown";

  console.log("# ArchiveMe device evidence guide");
  console.log("");
  console.log(
    `Identity: ${identity.productName} ${identity.semanticVersion}+${identity.buildNumber} @ ${identity.commitSha.slice(0, 7)}`,
  );
  console.log(`Pubspec:    ${pubspec.raw}`);
  console.log(`HEAD:       ${head.slice(0, 12)}`);

  const evaluation = evaluateRelease(manifest, { headSha: head });
  heading("Current release blockers");
  console.log(formatBlockerTable(evaluation.blockers, evaluation.issues));
  if (evaluation.releaseAllowed) {
    console.log("All machine gates pass — proceed with device evidence only if needed for audit trail.");
  }

  heading("Preflight commands (run on Mac now)");
  step(1, "npm run release:verify-focused-beta");
  step(2, "npm run release:preflight-ios");
  step(3, "Review release/DEVICE_EVIDENCE_RUNBOOK.md");

  heading("TestFlight upload (Mac + Xcode)");
  step(1, "cd apps/mobile && open ios/Runner.xcworkspace");
  step(2, "Bump pubspec +N if App Store Connect rejects duplicate build");
  step(
    3,
    `flutter build ipa --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app --dart-define=SOURCE_COMMIT_SHA=${head}`,
  );
  step(4, "Product → Archive → Organizer → Upload to App Store Connect");
  step(5, "Install on physical iPhone from TestFlight internal track");
  step(6, "Run smoke in apps/mobile/docs/TESTFLIGHT_MANUAL_QA.md");
  step(7, "Update mobile/evidence/testflight_tested.json + ios_signing_tested.json");
  step(8, "npm run validate:testflight-proof && npm run validate:ios-signing");
  step(9, "npm run release:apply-device-evidence -- --ios-only && npm run release:verify-focused-beta");

  heading("Offline sync re-verification (physical iPhone, same build)");
  step(1, "Settings → About → tap version label 7× to unlock developer tools");
  step(2, "Settings → Offline sync verify");
  step(3, "Airplane mode ON → record 5 eligible moments → lock baseline → force-quit → reopen");
  step(4, "Airplane mode OFF → sync → Export evidence");
  step(5, "Paste JSON into mobile/evidence/offline_sync_tested.json");
  step(6, "Confirm build_number and commit_sha match this release");
  step(7, "npm run validate:offline-sync-production");
  step(8, "Update sync_offline_conflict gate via npm run release:apply-device-evidence -- --ios-only");

  heading("Evidence templates");
  const templateDir = path.join(ROOT, "release/evidence/templates");
  if (fs.existsSync(templateDir)) {
    for (const file of fs.readdirSync(templateDir).sort()) {
      console.log(`- release/evidence/templates/${file}`);
    }
  }

  console.log("");
}

main();
