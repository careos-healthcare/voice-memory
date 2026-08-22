#!/usr/bin/env node
/**
 * Final measurable UI proof — runs static validators + Playwright UI/a11y/mobile/debug suites.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const PLAYWRIGHT_BROWSERS_PATH = path.join(
  ROOT,
  "node_modules",
  "playwright-core",
  ".local-browsers",
);

function runStaticUiChecks() {
  const failures = [];

  const REQUIRED_SYSTEM = [
    "apps/web/components/system/EmptyState.tsx",
    "apps/web/components/system/ErrorState.tsx",
    "apps/web/components/system/LoadingState.tsx",
    "apps/web/components/system/TrustNotice.tsx",
    "apps/web/components/system/PrivacyNotice.tsx",
    "apps/web/components/system/SyncStatus.tsx",
    "apps/web/components/system/BillingStatus.tsx",
    "apps/web/components/system/MemoryConfidence.tsx",
    "apps/web/components/system/index.ts",
  ];

  for (const rel of REQUIRED_SYSTEM) {
    if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
  }

  const header = fs.readFileSync(path.join(ROOT, "apps/web/components/SiteHeader.tsx"), "utf8");
  if (!header.includes('aria-label="Primary"')) failures.push("SiteHeader missing primary nav aria-label");
  if (header.includes("/debug")) failures.push("SiteHeader must not link to /debug");
  if (!header.includes("/account")) failures.push("SiteHeader missing Account nav");

  const pricingPage = fs.readFileSync(path.join(ROOT, "apps/web/app/pricing/page.tsx"), "utf8");
  if (!pricingPage.includes("PricingStaticShell")) {
    failures.push("pricing page must render PricingStaticShell (SSR)");
  }
  const pricingClient = fs.readFileSync(path.join(ROOT, "apps/web/app/pricing/PricingPageClient.tsx"), "utf8");
  for (const token of ["BillingStatus", "PrivacyNotice"]) {
    if (!pricingClient.includes(token)) failures.push(`pricing client missing ${token}`);
  }

  const archivePage = fs.readFileSync(path.join(ROOT, "apps/web/app/archive/page.tsx"), "utf8");
  if (!archivePage.includes("ArchivePageClient")) {
    failures.push("archive page must use ArchivePageClient");
  }
  if (!fs.existsSync(path.join(ROOT, "apps/web/components/archive/ArchiveSectionCard.tsx"))) {
    failures.push("missing ArchiveSectionCard");
  }

  const firstReturn = fs.readFileSync(
    path.join(ROOT, "apps/web/components/continuity/FirstReturnMoment.tsx"),
    "utf8",
  );
  if (!firstReturn.includes("MemoryConfidence")) failures.push("FirstReturnMoment must use MemoryConfidence");

  const journal = fs.readFileSync(path.join(ROOT, "apps/web/app/journal/page.tsx"), "utf8");
  if (!journal.includes("SyncStatus") && !journal.includes("JournalSyncStatus")) {
    failures.push("journal missing sync status");
  }
  if (!journal.includes("line-clamp") && !journal.includes("JournalArchiveRow")) {
    failures.push("journal missing compact archive rows");
  }

  const threads = fs.readFileSync(path.join(ROOT, "apps/web/app/threads/page.tsx"), "utf8");
  if (!threads.includes("ThreadListCompact")) failures.push("threads page must use ThreadListCompact");
  if (!threads.includes("LoadingState")) failures.push("threads page missing LoadingState");

  const entry = fs.readFileSync(path.join(ROOT, "apps/web/app/entry/[id]/page.tsx"), "utf8");
  if (!entry.includes("EntryPrimaryCallback")) {
    failures.push("entry page must use EntryPrimaryCallback for primary callback");
  }

  const recorderShell = fs.readFileSync(
    path.join(ROOT, "apps/web/components/capture/ZeroStateRecorderShell.tsx"),
    "utf8",
  );
  if (!recorderShell.includes("RecordCaptureChrome")) {
    failures.push("ZeroStateRecorderShell missing RecordCaptureChrome");
  }
  if (!recorderShell.includes("onUiPhaseChange")) {
    failures.push("ZeroStateRecorderShell must wire onUiPhaseChange");
  }

  const recorder = fs.readFileSync(path.join(ROOT, "apps/web/components/Recorder.tsx"), "utf8");
  if (!recorder.includes("onUiPhaseChange")) {
    failures.push("Recorder missing onUiPhaseChange");
  }
  if (!recorder.includes("useReducedMotion")) {
    failures.push("Recorder must respect reduced motion");
  }

  const globals = fs.readFileSync(path.join(ROOT, "apps/web/app/globals.css"), "utf8");
  if (!globals.includes("prefers-reduced-motion: reduce")) {
    failures.push("globals.css missing prefers-reduced-motion rules");
  }
  if (!globals.includes(":focus-visible")) {
    failures.push("globals.css missing focus-visible styles");
  }

  const readiness = fs.readFileSync(
    path.join(ROOT, "packages/shared/lib/server/production-readiness.ts"),
    "utf8",
  );
  if (!readiness.includes("VOICEMEMORY_UI_E2E")) {
    failures.push("production-readiness must document VOICEMEMORY_UI_E2E for UI smoke only");
  }

  const instrumentation = fs.readFileSync(path.join(ROOT, "apps/api/instrumentation.ts"), "utf8");
  if (!instrumentation.includes('NEXT_RUNTIME === "edge"')) {
    failures.push("instrumentation must skip edge runtime");
  }

  if (!fs.existsSync(path.join(ROOT, "e2e/ui-mobile-375.spec.ts"))) {
    failures.push("missing e2e/ui-mobile-375.spec.ts");
  }
  if (!fs.existsSync(path.join(ROOT, "e2e/ui-a11y.spec.ts"))) {
    failures.push("missing e2e/ui-a11y.spec.ts");
  }
  if (!fs.existsSync(path.join(ROOT, "scripts/validate-accessibility-strict.mjs"))) {
    failures.push("missing scripts/validate-accessibility-strict.mjs");
  }
  if (!fs.existsSync(path.join(ROOT, "apps/web/components/layout/PrimaryMain.tsx"))) {
    failures.push("missing components/layout/PrimaryMain.tsx");
  }
  const a11ySpec = fs.existsSync(path.join(ROOT, "e2e/ui-a11y.spec.ts"))
    ? fs.readFileSync(path.join(ROOT, "e2e/ui-a11y.spec.ts"), "utf8")
    : "";
  if (a11ySpec.includes("toBeLessThanOrEqual(4)")) {
    failures.push("ui-a11y must not allow contrast exceptions (remove toBeLessThanOrEqual(4))");
  }
  if (!fs.existsSync(path.join(ROOT, "e2e/ui-debug-regression.spec.ts"))) {
    failures.push("missing e2e/ui-debug-regression.spec.ts");
  }
  if (!fs.existsSync(path.join(ROOT, "apps/web/components/pricing/PricingStaticShell.tsx"))) {
    failures.push("missing PricingStaticShell");
  }

  for (const rel of [
    "packages/shared/lib/hooks/use-reduced-motion.ts",
    "apps/web/components/capture/RecordCaptureChrome.tsx",
    "apps/web/components/memory/ThreadListCard.tsx",
    "apps/web/components/entry/EntryPrimaryCallback.tsx",
  ]) {
    if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
  }

  const middleware = fs.readFileSync(path.join(ROOT, "apps/web/middleware.ts"), "utf8");
  if (!middleware.includes("isDeprecatedDebugPath")) {
    failures.push("middleware must retire /debug");
  }
  if (!middleware.includes("/internal")) failures.push("middleware must guard /internal");
  if (!middleware.includes("status: 404")) failures.push("middleware must return 404 when blocked");

  const account = fs.readFileSync(path.join(ROOT, "apps/web/app/account/page.tsx"), "utf8");
  if (!account.includes("DELETE_ACCOUNT_CONFIRM_PHRASE")) {
    failures.push("account page missing delete confirmation phrase");
  }

  if (!fs.existsSync(path.join(ROOT, "e2e/ui-smoke.spec.ts"))) {
    failures.push("missing e2e/ui-smoke.spec.ts");
  }

  if (failures.length) {
    console.error("validate-ui static checks failed:\n", failures.join("\n"));
    process.exit(1);
  }
  console.log("validate-ui static checks ok");
}

const baseEnv = {
  ...process.env,
  CI: "1",
  EMAIL_DISABLED: "true",
  VOICEMEMORY_UI_E2E: "1",
  PLAYWRIGHT_BROWSERS_PATH,
  AUTH_SECRET:
    process.env.AUTH_SECRET ?? "e2e-test-auth-secret-min-32-chars-long",
};

const steps = [
  ["validate-ui static", () => runStaticUiChecks()],
  ["validate:ux-copy", "npm", ["run", "validate:ux-copy"]],
  ["validate:accessibility-strict", "npm", ["run", "validate:accessibility-strict"]],
  [
    "playwright install chromium",
    "npx",
    ["playwright", "install", "chromium"],
  ],
  ["build", "npm", ["run", "build"]],
  ["test:e2e:ui (smoke)", "npx", ["playwright", "test", "-c", "playwright.ui.config.ts", "--project=smoke"]],
  ["test:e2e:ui (mobile 375)", "npx", ["playwright", "test", "-c", "playwright.ui.config.ts", "--project=mobile"]],
  ["test:a11y", "npx", ["playwright", "test", "-c", "playwright.ui.config.ts", "--project=a11y"]],
  ["debug regression", "npx", ["playwright", "test", "-c", "playwright.ui.config.ts", "--project=debug"]],
];

let failed = false;

for (const step of steps) {
  const name = step[0];
  console.log(`\n— ${name} —`);
  if (typeof step[1] === "function") {
    try {
      step[1]();
    } catch (error) {
      console.error(`FAILED: ${name}`, error);
      failed = true;
      break;
    }
    continue;
  }
  const [, cmd, args] = step;
  const result = spawnSync(cmd, args, {
    stdio: "inherit",
    env: baseEnv,
  });
  if (result.status !== 0) {
    console.error(`FAILED: ${name}`);
    failed = true;
    break;
  }
}

if (failed) {
  console.error("\nvalidate-ui-final FAILED");
  process.exit(1);
}

console.log("\nvalidate-ui-final ok");
process.exit(0);
