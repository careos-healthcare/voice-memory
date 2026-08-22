#!/usr/bin/env node
/**
 * Reactivated insight-science validation for archive_theory / agreement layer.
 *
 * Shared TypeScript validators (packages/shared) run everywhere.
 * Mobile Dart suites run when `flutter` is available (local + flutter-gates CI).
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const MOBILE_DIR = path.join(ROOT, "apps/mobile");
const SUITE_DIR = path.join(ROOT, "scripts/deferred_v2_insight_science");

const MOBILE_THEORY_TESTS = [
  "test/archive_theory_engine_test.dart",
  "test/theory_ranking_engine_test.dart",
  "test/archive_agreement_service_test.dart",
  "test/archive_primary_theory_validation_test.dart",
  "test/archive_quality_validation_test.dart",
];

/** Internal scoring validators stay deferred — not product-gated in V1. */
const DEFERRED_INTERNAL_SCORING = [
  "validate-insight-ingredient-optimizer.mjs",
  "validate-a-tier-prioritization.mjs",
];

const ACTIVE_SHARED_VALIDATORS = [];

/**
 * These six validators assert copy and structure of consumer web surfaces that
 * were retired in the monorepo move: every file they read now lives under
 * `apps/web/archived-*` "for reference", and production web is marketing,
 * legal, support and beta only (see apps/web/archived-components/README.md).
 *
 * They are NOT repointed at the archived copies. A validator that greps code
 * nobody ships reports success about nothing — the exact false reassurance this
 * gate exists to prevent. They are deferred instead, and the deferral is
 * self-expiring in both directions: if the live surface comes back, the
 * deferral is stale and this script fails until the validator is re-activated;
 * if the archived reference is deleted too, the content is genuinely gone and
 * this script fails until the validator is deleted with it.
 */
const ARCHIVED_WEB_SURFACE_VALIDATORS = [
  {
    script: "validate-breakthrough-tracking.mjs",
    live: "apps/web/components/internal/BreakthroughTrackingPanel.tsx",
    archived: "apps/web/archived-components/_archived/internal/BreakthroughTrackingPanel.tsx",
  },
  {
    script: "validate-insight-scorecard.mjs",
    live: "apps/web/components/insights/InsightScorecardPanel.tsx",
    archived: "apps/web/archived-components/_archived/insights/InsightScorecardPanel.tsx",
  },
  {
    script: "validate-notification-effectiveness.mjs",
    live: "apps/web/components/internal/NotificationEffectivenessPanel.tsx",
    archived:
      "apps/web/archived-components/_archived/internal/NotificationEffectivenessPanel.tsx",
  },
  {
    script: "validate-session-movement-summary.mjs",
    live: "apps/web/components/archive/SessionMovementSummary.tsx",
    archived: "apps/web/archived-components/_archived/archive/SessionMovementSummary.tsx",
  },
  {
    script: "validate-theory-resolution.mjs",
    live: "apps/web/components/discover/TheoryChangeFeed.tsx",
    archived: "apps/web/archived-components/_archived/discover/TheoryChangeFeed.tsx",
  },
  {
    script: "validate-theory-volatility.mjs",
    live: "apps/web/components/internal/TheoryVolatilityPanel.tsx",
    archived: "apps/web/archived-components/_archived/internal/TheoryVolatilityPanel.tsx",
  },
];

const failures = [];

function run(label, result) {
  if (result.status !== 0) {
    failures.push(label);
  }
}

const flutterAvailable =
  spawnSync("flutter", ["--version"], { stdio: "ignore" }).status === 0;

if (flutterAvailable) {
  console.log("==> mobile theory / agreement dart suites");
  const mobile = spawnSync("flutter", ["test", ...MOBILE_THEORY_TESTS], {
    cwd: MOBILE_DIR,
    stdio: "inherit",
    env: process.env,
  });
  run("mobile theory dart suites", mobile);
} else {
  console.log("==> skipping mobile theory dart suites (flutter not on PATH)");
}

for (const script of ACTIVE_SHARED_VALIDATORS) {
  const rel = path.join("scripts/deferred_v2_insight_science", script);
  process.stdout.write(`\n==> ${rel}\n`);
  const result = spawnSync("node", ["--import", "tsx", rel], {
    cwd: ROOT,
    stdio: "inherit",
    env: process.env,
  });
  run(rel, result);
}

process.stdout.write("\n==> deferred: validators for retired consumer web surfaces\n");
for (const entry of ARCHIVED_WEB_SURFACE_VALIDATORS) {
  const liveExists = fs.existsSync(path.join(ROOT, entry.live));
  const archivedExists = fs.existsSync(path.join(ROOT, entry.archived));

  if (liveExists) {
    failures.push(
      `${entry.script}: deferral is STALE — ${entry.live} is live again. ` +
        `Move this script back into ACTIVE_SHARED_VALIDATORS.`,
    );
  } else if (!archivedExists) {
    failures.push(
      `${entry.script}: ${entry.live} is gone and so is its archived copy ` +
        `${entry.archived}. The surface no longer exists in any form — delete this ` +
        `validator instead of deferring it.`,
    );
  } else {
    console.log(`  NOT ENFORCED  ${entry.script} — ${entry.live} archived, not shipped`);
  }
}

const deferredCount = fs
  .readdirSync(SUITE_DIR)
  .filter((name) => name.startsWith("validate-") && name.endsWith(".mjs")).length;

if (failures.length > 0) {
  console.error(`\nvalidate-insight-science failed:\n${failures.join("\n")}`);
  process.exit(1);
}

const mobileNote = flutterAvailable
  ? `${MOBILE_THEORY_TESTS.length} mobile suites + `
  : "";

const unenforced =
  ARCHIVED_WEB_SURFACE_VALIDATORS.length + DEFERRED_INTERNAL_SCORING.length;

// Say this in the log and in the Actions annotation. A reader who sees this
// step green must not conclude that insight-science was checked on web.
console.log(
  `\n::warning title=Insight-science partially unenforced::` +
    `${ARCHIVED_WEB_SURFACE_VALIDATORS.length} insight-science validators are NOT ENFORCED — ` +
    `they target consumer web surfaces retired to apps/web/archived-*. ` +
    `Insight-science on the shipping product is covered by the mobile Dart suites` +
    `${flutterAvailable ? "" : ", which did not run here (flutter not on PATH)"}.`,
);

console.log(
  `\nvalidate-insight-science ok (${mobileNote}${ACTIVE_SHARED_VALIDATORS.length}/${deferredCount} shared validators enforced, ${unenforced} deferred)`,
);
