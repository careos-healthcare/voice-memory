#!/usr/bin/env node
/**
 * ArchiveMe pre-production review export (app21).
 * Output: /Users/chiragpatel/Desktop/app21
 * 10 TextEdit .txt files + 4 markdown reports + export summary in file 10.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT_DIR = "/Users/chiragpatel/Desktop/app21";

const SKIP_DIR_NAMES = new Set([
  ".next",
  "node_modules",
  ".git",
  "coverage",
  "test-results",
  "dist",
  "build",
  ".turbo",
  "playwright-report",
  ".dart_tool",
  ".gradle",
  "Pods",
]);

const SKIP_FILE_NAMES = new Set([
  "package-lock.json",
  "yarn.lock",
  "pnpm-lock.yaml",
]);

const BINARY_EXT = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".ico",
  ".webp",
  ".woff",
  ".woff2",
  ".ttf",
  ".eot",
  ".mp3",
  ".wav",
  ".m4a",
  ".zip",
  ".jar",
  ".aar",
  ".keystore",
  ".p12",
  ".xcworkspace",
  ".xcodeproj",
]);

const TEXT_EXTENSIONS = new Set([
  ".ts",
  ".tsx",
  ".js",
  ".mjs",
  ".cjs",
  ".dart",
  ".json",
  ".md",
  ".yaml",
  ".yml",
  ".xml",
  ".plist",
  ".gradle",
  ".kts",
  ".properties",
  ".swift",
  ".kt",
  ".html",
  ".css",
  ".txt",
  ".sql",
  ".env.example",
  ".pro",
]);

const MAX_SINGLE_FILE_BYTES = 150_000;
const MAX_OUTPUT_BYTES = 5_500_000;

const TXT_OUTPUTS = [
  {
    id: "01",
    file: "01_EXECUTIVE_PREPRODUCTION_REVIEW.txt",
    title: "Executive Pre-Production Review",
    synthesisOnly: true,
  },
  {
    id: "02",
    file: "02_PRODUCT_AND_UX_ARCHITECTURE.txt",
    title: "Product and UX Architecture",
  },
  {
    id: "03",
    file: "03_ARCHIVE_ENGINE_AND_BELIEF_SYSTEM.txt",
    title: "Archive Engine and Belief System",
  },
  {
    id: "04",
    file: "04_ACTIVATION_RETENTION_AND_CONVERSION.txt",
    title: "Activation, Retention, and Conversion",
  },
  {
    id: "05",
    file: "05_WEB_APP_COMPLETE_SOURCE.txt",
    title: "Web App Complete Source",
  },
  {
    id: "06",
    file: "06_FLUTTER_MOBILE_COMPLETE_SOURCE.txt",
    title: "Flutter Mobile Complete Source",
  },
  {
    id: "07",
    file: "07_AUTH_BILLING_AND_SECURITY.txt",
    title: "Auth, Billing, and Security",
  },
  {
    id: "08",
    file: "08_MOBILE_READINESS_AND_STORE_PROOF.txt",
    title: "Mobile Readiness and Store Proof",
  },
  {
    id: "09",
    file: "09_INTERNAL_SYSTEMS_AND_VALIDATORS.txt",
    title: "Internal Systems and Validators",
  },
  {
    id: "10",
    file: "10_FINAL_AUDIT_AND_LAUNCH_PLAN.txt",
    title: "Final Audit and Launch Plan",
    synthesisOnly: true,
  },
];

const MD_REPORTS = [
  "PREPRODUCTION_AUDIT.md",
  "MOBILE_GAP_REPORT.md",
  "STORE_SUBMISSION_REPORT.md",
  "ACTIVATION_VALIDATION_REPORT.md",
];

const REDACT_PATTERNS = [
  [/sk_live_[a-zA-Z0-9]+/g, "sk_live_[REDACTED]"],
  [/sk_test_[a-zA-Z0-9]+/g, "sk_test_[REDACTED]"],
  [/pk_live_[a-zA-Z0-9]+/g, "pk_live_[REDACTED]"],
  [/pk_test_[a-zA-Z0-9]+/g, "pk_test_[REDACTED]"],
  [/whsec_[a-zA-Z0-9]+/g, "whsec_[REDACTED]"],
  [/price_[a-zA-Z0-9]+/g, "price_[REDACTED]"],
  [/sk-[a-zA-Z0-9]{20,}/g, "sk-[REDACTED]"],
  [/re_[a-zA-Z0-9]{20,}/g, "re_[REDACTED]"],
  [/DATABASE_URL\s*=\s*[^\s\n#'"]+/gi, "DATABASE_URL=[REDACTED_DATABASE_URL]"],
  [
    /(POSTGRES_URL|SUPABASE_URL|OPENAI_API_KEY|RESEND_API_KEY|STRIPE_SECRET_KEY|STRIPE_WEBHOOK_SECRET|NEXTAUTH_SECRET|AUTH_SECRET|SESSION_SECRET|CAPTURE_ATTEST_SECRET)\s*=\s*[^\s\n#'"]+/gi,
    "$1=[REDACTED]",
  ],
  [/"DATABASE_URL"\s*:\s*"[^"]*"/gi, '"DATABASE_URL":"[REDACTED_DATABASE_URL]"'],
  [
    /"(POSTGRES_URL|OPENAI_API_KEY|RESEND_API_KEY|STRIPE_SECRET_KEY|STRIPE_WEBHOOK_SECRET|NEXTAUTH_SECRET)"\s*:\s*"[^"]*"/gi,
    '"$1":"[REDACTED]"',
  ],
  [/Bearer\s+[a-zA-Z0-9._-]{20,}/g, "Bearer [REDACTED_TOKEN]"],
  [/eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/g, "[REDACTED_JWT]"],
  [/postgres(?:ql)?:\/\/[^\s"'`]+/gi, "postgresql://[REDACTED_DATABASE_URL]"],
  [/mongodb(?:\+srv)?:\/\/[^\s"'`]+/gi, "mongodb://[REDACTED_DATABASE_URL]"],
  [
    /-----BEGIN (?:RSA |EC )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC )?PRIVATE KEY-----/g,
    "[REDACTED_PRIVATE_KEY]",
  ],
];

function redactContent(text, relPath) {
  if (/\.env/i.test(relPath) && !/\.example$/i.test(relPath)) {
    return "[REDACTED — environment file omitted]\n";
  }
  let out = text;
  for (const [pattern, replacement] of REDACT_PATTERNS) {
    out = out.replace(pattern, replacement);
  }
  return out;
}

function shouldSkipDir(name, parentRel = "") {
  if (name.startsWith(".") && name !== ".well-known") return true;
  if (SKIP_DIR_NAMES.has(name)) return true;
  if (name === "build" && /voicememory_mobile\/(android|ios)\//.test(parentRel)) return true;
  return false;
}

function isTextFile(relPath) {
  const base = path.basename(relPath);
  if (SKIP_FILE_NAMES.has(base)) return false;
  if (/\.env/i.test(relPath) && !/\.example$/i.test(relPath)) return false;
  const ext = path.extname(relPath).toLowerCase();
  if (BINARY_EXT.has(ext)) return false;
  if (TEXT_EXTENSIONS.has(ext)) return true;
  if (relPath.endsWith("Dockerfile") || relPath.endsWith("Makefile")) return true;
  return false;
}

function walkFiles(dir, base = "") {
  const results = [];
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return results;
  }
  for (const entry of entries) {
    if (entry.name === "export-app21.mjs" && base === "scripts") continue;
    const rel = base ? `${base}/${entry.name}` : entry.name;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (shouldSkipDir(entry.name, rel)) continue;
      results.push(...walkFiles(full, rel));
    } else if (entry.isFile() && isTextFile(rel)) {
      results.push(rel);
    }
  }
  return results;
}

function classifyApp21(rel) {
  const p = rel.replace(/\\/g, "/");

  if (/\.dart$/i.test(p)) return "06";
  if (p.startsWith("apps/voicememory_mobile/")) {
    if (/\.(png|jpg|jpeg|gif|ico|webp|storyboard)$/i.test(p)) return null;
    return "06";
  }

  if (
    p.startsWith("lib/mobile/") ||
    p.startsWith("mobile/") ||
    (p.startsWith("docs/") && /MOBILE/i.test(p)) ||
    p.startsWith("types/mobile-") ||
    p.startsWith("app/internal/mobile-") ||
    p.startsWith("lib/notifications/push") ||
    p.startsWith("components/internal/Mobile")
  ) {
    return "08";
  }

  if (
    p.startsWith("app/internal/") ||
    p.startsWith("lib/internal/") ||
    p.startsWith("components/internal/") ||
    p.startsWith("scripts/validate") ||
    p.startsWith("scripts/generate-mobile") ||
    p.startsWith("scripts/run-") ||
    p === "package.json"
  ) {
    return "09";
  }

  if (
    p.startsWith("lib/auth/") ||
    p.startsWith("components/auth/") ||
    p.startsWith("app/api/") ||
    p.startsWith("lib/server/") ||
    p.startsWith("lib/billing/") ||
    p.startsWith("lib/entitlement/") ||
    p.startsWith("lib/persistence/") ||
    p.startsWith("lib/proof/") ||
    p.startsWith("lib/reliability/") ||
    p.startsWith("lib/sync/") ||
    p.startsWith("lib/openai-budget/") ||
    p.startsWith("middleware.ts") ||
    p === "middleware.ts" ||
    p.startsWith("supabase/")
  ) {
    return "07";
  }

  if (
    p.startsWith("lib/archive/") ||
    p.startsWith("components/archive/") ||
    p.startsWith("types/living-archive") ||
    p.startsWith("types/archive-") ||
    p.startsWith("types/belief-") ||
    p.startsWith("types/evidence-") ||
    p.startsWith("lib/memory-export") ||
    p.startsWith("lib/product/archive") ||
    p.startsWith("lib/refinement/") ||
    p.startsWith("lib/theories/") ||
    p.startsWith("lib/discover/") ||
    p.startsWith("lib/blind-spots/") ||
    p.startsWith("components/blind-spots/") ||
    p.startsWith("components/discover/") ||
    p.startsWith("components/theories/") ||
    p.startsWith("app/archive-belief/") ||
    p.startsWith("app/archive/") ||
    p.startsWith("app/memory/") ||
    p.startsWith("app/timeline/")
  ) {
    return "03";
  }

  if (
    p.startsWith("lib/onboarding/") ||
    p.startsWith("components/onboarding/") ||
    p.startsWith("lib/retention/") ||
    p.startsWith("lib/activation") ||
    p.startsWith("lib/product/activation") ||
    p.startsWith("lib/founder-test/") ||
    p.startsWith("lib/metrics/") ||
    p.startsWith("lib/marketing/") ||
    p.startsWith("lib/monetization/") ||
    p.startsWith("lib/organic-referral") ||
    p.startsWith("lib/paywall") ||
    p.startsWith("types/onboarding") ||
    p.startsWith("types/retention") ||
    p.startsWith("app/internal/north-star") ||
    p.startsWith("app/internal/archive/page") ||
    p.startsWith("lib/internal/founder")
  ) {
    return "04";
  }

  if (
    p === "app/page.tsx" ||
    p.startsWith("app/record/") ||
    p.startsWith("app/discover/") ||
    p.startsWith("app/blind-spots/") ||
    p.startsWith("app/welcome/") ||
    p.startsWith("app/export/") ||
    p.startsWith("app/pricing/") ||
    p.startsWith("app/settings/") ||
    p.startsWith("app/account/") ||
    p.startsWith("components/Recorder") ||
    p.startsWith("components/ActivationOnboarding") ||
    p.startsWith("components/layout/") ||
    p.startsWith("components/SiteHeader") ||
    p.startsWith("lib/product-copy") ||
    p.startsWith("lib/tester-onboarding") ||
    p.startsWith("lib/activation-guidance") ||
    p.startsWith("docs/") ||
    p === "AGENTS.md" ||
    p === "CLAUDE.md"
  ) {
    return "02";
  }

  if (
    p.startsWith("app/") ||
    p.startsWith("components/") ||
    p.startsWith("lib/") ||
    p.startsWith("types/") ||
    p.startsWith("e2e/") ||
    p.startsWith("public/")
  ) {
    return "05";
  }

  if (p.startsWith("scripts/")) return "09";
  return "05";
}

function readFileSafe(rel) {
  const full = path.join(ROOT, rel);
  let stat;
  try {
    stat = fs.statSync(full);
  } catch {
    return null;
  }
  if (!stat.isFile() || stat.size > MAX_SINGLE_FILE_BYTES) {
    return {
      truncated: true,
      content: `[Omitted — file too large (${stat?.size ?? "?"} bytes): ${rel}]\n`,
    };
  }
  return { truncated: false, content: redactContent(fs.readFileSync(full, "utf8"), rel) };
}

function formatFileBlock(rel, content) {
  const sep = "=".repeat(72);
  return `${sep}\nFILE: ${rel}\n${sep}\n\n${content}\n\n`;
}

function buildToc(meta, files) {
  return [
    "TABLE OF CONTENTS",
    "=================",
    `Export: ${meta.file}`,
    `Title: ${meta.title}`,
    `Generated: ${new Date().toISOString()}`,
    `Root: ${ROOT}`,
    "",
    `Files included (${files.length}):`,
    "",
    ...files.map((f, i) => `${String(i + 1).padStart(4, " ")}. ${f}`),
    "",
    "—".repeat(72),
    "",
  ].join("\n");
}

function listRoutes(files) {
  const routes = files
    .filter((f) => /^app\/.+\/page\.tsx$/.test(f))
    .map((f) => "/" + f.replace(/^app\//, "").replace(/\/page\.tsx$/, ""))
    .sort();
  return {
    publicRoutes: routes.filter((r) => !r.startsWith("/internal") && !r.startsWith("/debug")),
    internalRoutes: routes.filter((r) => r.startsWith("/internal") || r.startsWith("/debug")),
    apiRoutes: files
      .filter((f) => f.startsWith("app/api/") && f.endsWith("/route.ts"))
      .map((f) => `/api/${f.replace(/^app\/api\//, "").replace(/\/route\.ts$/, "")}`)
      .sort(),
  };
}

function flutterRouteMap() {
  const router = readFileSafe("apps/voicememory_mobile/lib/router/app_router.dart");
  if (!router) return "(router not found)";
  const paths = [...router.content.matchAll(/path:\s*'([^']+)'/g)].map((m) => m[1]);
  return [...new Set(paths)].sort().map((p) => `  ${p}`).join("\n");
}

async function loadReports() {
  try {
    const { buildMobileProductionReadinessReport } = await import(
      path.join(ROOT, "lib/mobile/mobile-production-readiness.ts")
    );
    const { buildMobileFirstClassReport } = await import(
      path.join(ROOT, "lib/mobile/mobile-first-class-report.ts")
    );
    const { buildMobileParityReport, formatParityReportMarkdown } = await import(
      path.join(ROOT, "lib/mobile/mobile-parity-report.ts")
    );
    const { getPaymentStackAudit } = await import(
      path.join(ROOT, "lib/entitlement/payment-stack.ts")
    );
    return {
      mobileReadiness: buildMobileProductionReadinessReport(),
      mobileFirstClass: buildMobileFirstClassReport(),
      parity: buildMobileParityReport(),
      parityMd: formatParityReportMarkdown(buildMobileParityReport()),
      payment: getPaymentStackAudit(),
    };
  } catch (err) {
    return {
      error: String(err),
      mobileReadiness: null,
      mobileFirstClass: null,
      parity: null,
      parityMd: "",
      payment: null,
    };
  }
}

function pillarLine(p) {
  if (!p) return "UNKNOWN";
  return `${p.status} (${p.passing}/${p.total}) — ${p.summary}`;
}

function generateExecutiveReview(reports, routes, stats) {
  const mr = reports.mobileReadiness;
  const mfc = reports.mobileFirstClass;
  const pay = reports.payment;

  return `
================================================================================
EXECUTIVE PRE-PRODUCTION REVIEW (generated)
================================================================================
Generated: ${new Date().toISOString()}
Repository: ${ROOT}

READINESS SCORES (evidence-based where noted)
---------------------------------------------
Product readiness:     ${mr ? pillarLine(mr.productReadiness) : "See MOBILE_READINESS_REPORT.md"}
Mobile readiness:      ${mr ? `${mr.passingCount} passing / ${mr.failingCount} failing / ${mr.unknownCount} unknown checklist items` : "N/A"}
Store readiness:       ${mr ? pillarLine(mr.storeReadiness) : "N/A"}
Distribution readiness:${mr ? pillarLine(mr.distributionReadiness) : "N/A"}
Revenue readiness:     ${pay ? pay.summary : "Stripe when env configured; RevenueCat absent on mobile"}

Mobile primary verdict: ${mfc?.verdict ?? "N/A"}
${mfc?.verdictReasons?.map((r) => `  • ${r}`).join("\n") ?? ""}

ARCHIVE MOAT ANALYSIS
---------------------
• Longitudinal belief + evidence archive (not single-session chat).
• State delta, living archive presentation, reputation/trust signals on web + mobile.
• Pattern/blind-spot and theory-change loops require return visits — compounding data moat.
• Guest-first auth protects value at moments (export, paywall, protect archive).
• Weakness: cold start (5 reflections before full pattern proof); mobile still companion-tier billing.

LAUNCH BLOCKERS
---------------
${mfc?.validationFailures?.map((f) => `• ${f}`).join("\n") ?? "• Run validate:mobile-primary-product for current list"}
• Store evidence files largely absent (TestFlight, signing, IAP, restore, push).
• Android release may still use debug signing until release keystore evidenced.
• Native restore / RevenueCat not integrated on Flutter.

RISKS
-----
• Optimizing founder dashboards over user-facing proof.
• Browser-only Stripe on mobile breaks PRIMARY_PLATFORM claim.
• Push notifications not store-ready (native verification placeholder).
• Large validator surface — risk of false confidence without device evidence.

MISSING PROOF
-------------
• mobile/evidence/*.json for store checklist (TestFlight, purchases, restore, signing).
• 10+ founder tests with pay-after-value signal.
• End-to-end paid entitlement on production Stripe.
• Physical device native push verification (both platforms).

FINAL VERDICT
-------------
Pre-production web product: DEEP — ship founder pilot on web with discipline.
App Store primary platform: NO-GO until native IAP, restore, and evidence committed.
Commercial: prove 4→5 reflection completion and value-moment conversion before paid acquisition.

INVENTORY
---------
Public routes: ${routes.publicRoutes.length}
Internal routes: ${routes.internalRoutes.length}
API routes: ${routes.apiRoutes.length}
Source files scanned: ${stats.totalSourceFiles}
Dart files: ${stats.dartCount}
Validate scripts: ${stats.validateScriptCount}
`;
}

function generateProductArchitecture(routes) {
  return `
================================================================================
PRODUCT & UX ARCHITECTURE (generated)
================================================================================

ROUTE MAP — WEB PUBLIC (${routes.publicRoutes.length})
${routes.publicRoutes.map((r) => `  ${r}`).join("\n")}

ROUTE MAP — WEB INTERNAL / DEBUG (${routes.internalRoutes.length})
${routes.internalRoutes.slice(0, 50).map((r) => `  ${r}`).join("\n")}
${routes.internalRoutes.length > 50 ? `  … +${routes.internalRoutes.length - 50} more` : ""}

API ROUTES
${routes.apiRoutes.map((r) => `  ${r}`).join("\n")}

NAVIGATION ARCHITECTURE
-----------------------
Web: Archive-first home at /archive-belief and /memory; record at /record; changes at /discover;
     account/settings/export/pricing as satellite routes.
Mobile: Bottom nav Record | Archive | Changes | Account; initialLocation /archive-belief;
        onboarding gate → /onboarding; full-screen tools via /archive-tool/:tool, /pricing, /export.

ARCHIVE-FIRST UX
----------------
Belief → Status → State Delta → Pulse → Trust → Evidence (web EvidenceArchiveHome + mobile ArchiveBeliefScreen).

ONBOARDING
----------
Web: ActivationOnboarding, tester copy, calm comprehension modules (lib/onboarding/*).
Mobile: /onboarding OnboardingScreen + onboarding_gate redirect.

ARCHIVE ACTIVITY
----------------
Web: Archive Activity panel (living archive); discover reframed from raw theory feed.
Mobile: /discover simplified local diff.

RECORD FLOW
-----------
Recorder.tsx (web) + record_screen.dart (mic permission, capture attest, transcribe, analyze).

PROTECT ARCHIVE FLOW
--------------------
Guest-first auth; ProtectArchiveBanner (mobile); auth trigger rules at value moments.

MOBILE ARCHITECTURE
-------------------
Flutter app: apps/voicememory_mobile — go_router, AppServices, local journal + API sync when signed in.

INFORMATION HIERARCHY
---------------------
Primary: working belief + archive movement.
Secondary: blind spots, theory changes, open loops.
Tertiary: internal founder metrics (not in mobile app).

FLUTTER ROUTES
--------------
${flutterRouteMap()}
`;
}

function generateArchiveEngineSummary() {
  return `
================================================================================
ARCHIVE ENGINE & BELIEF SYSTEM (generated index)
================================================================================

Modules included in this export part:
• Belief engine — lib/archive/archive-belief*, belief dossier, archive-belief-system validators
• Reputation / Trust — archive-reputation, ArchiveReputationCard, trust presentation
• Survival / Accuracy — mobile archive_tool_screen; web archive tooling
• Contradictions — blind-spots engines (simplified on mobile)
• Activity — archive-activity, living-archive, discover/theory feeds
• State Delta — archive-state-delta, ArchiveStateDeltaCard
• Living Archive — living-archive.ts, pulse, status, memory, open questions
• Ownership — export, protect archive, archive guarantees
• Timeline — belief-change-timeline, updates, feelings-timeline
• Evidence Locker — evidence locker components + types
• Dossier — belief dossier types and UI
• Progress — archive-value-progress, archive-maturity, effort-compounds

See file blocks below for full source.
`;
}

function generateActivationSummary() {
  return `
================================================================================
ACTIVATION, RETENTION & CONVERSION (generated index)
================================================================================

• Activation — activation-guidance, first-blind-spot, pattern-activation, immediate-engagement
• Curiosity — theory-curiosity, open-loops, discovery-loop
• Return — returning-home, archive-reason-to-return, callback-learning, resurfacing
• Attachment — archive-attachment, archive-voice, continuity-reinforcement
• Referral — organic-referral
• Paywall attribution — paywall-attribution, value-moment paywall
• Conversion — monetization validators, pricing, entitlements
• North Star — /internal/north-star (5 metrics)
• Founder focus — founder-priority, feature-filter, validate:founder-focus
`;
}

function generateFlutterSummary(allFiles) {
  const dart = allFiles.filter((f) => f.endsWith(".dart"));
  const ios = allFiles.filter((f) => f.startsWith("apps/voicememory_mobile/ios/"));
  const android = allFiles.filter((f) => f.startsWith("apps/voicememory_mobile/android/"));
  return `
================================================================================
FLUTTER MOBILE (generated index)
================================================================================

Dart files in repo: ${dart.length}
iOS config/docs files: ${ios.length}
Android config files: ${android.length}

ROUTE MAP
---------
${flutterRouteMap()}

ANDROID SUMMARY
---------------
• RECORD_AUDIO + INTERNET in AndroidManifest
• Release signing: check build.gradle.kts for debug vs release keystore

iOS SUMMARY
-----------
• NSMicrophoneUsageDescription in Info.plist
• Runner.xcworkspace; push entitlement documented out of v1 in checklist

MOBILE ARCHIVE / BILLING / PUSH
-------------------------------
• archive_belief_screen, living_archive_mobile widgets
• pricing_screen → Stripe browser checkout
• native_push_verification screen + flutter_local_notifications
`;
}

function generateFinalAudit(routes, reports, exportStats) {
  return `
================================================================================
FINAL AUDIT & LAUNCH PLAN (generated)
================================================================================

COMPETITOR BENCHMARK
--------------------
Day One / Reflect (journaling)
  • They win: daily habit, beautiful timeline, zero AI complexity.
  • ArchiveMe wins: belief/evidence archive, pattern discovery, theory change over time.

ChatGPT / general AI
  • They win: instant answers, drafting, no reflection count gate.
  • ArchiveMe wins: private longitudinal archive, uncomfortable accuracy at 5+ reflections.

Voice-note AI apps
  • They win: fast capture + summary in one session.
  • ArchiveMe wins: archive moat, reputation/trust framing, export/protect ownership story.

STRENGTHS
---------
• Archive-as-product UX depth (belief, delta, living archive, evidence locker).
• Extensive validation + founder instrumentation.
• Guest-first auth + value-moment paywall timing.
• Flutter primary nav aligned to archive-first story.

WEAKNESSES
----------
• Mobile COMPANION_APP verdict — browser checkout, no restore.
• Store evidence mostly FAILING/UNKNOWN.
• Cold-start friction to first blind spot.
• Internal surface area >> user-facing proof.

LAUNCH CHECKLIST
----------------
[ ] Stripe live + webhook on staging
[ ] 10 founder tests with pay intent
[ ] mobile/evidence testflight + signing + IAP + restore
[ ] validate:mobile-primary-product → PRIMARY_PLATFORM
[ ] Push native verification on physical devices
[ ] 4→5 reflection rate measured

REVENUE SCENARIOS (illustrative)
--------------------------------
• 500 subs × £10 ≈ £5k MRR — requires strong activation conversion.
• 5,000 subs × £10 ≈ £50k MRR — requires proven paywall-after-value + retention.

30-DAY LAUNCH PLAN
------------------
Week 1: Close mobile IAP + restore; commit store evidence JSON.
Week 2: Founder pilot cohort; measure 4→5 and paywall CTA.
Week 3: TestFlight/internal Play upload; fix signing.
Week 4: Go/no-go on paid acquisition from conversion data only.

FINAL RECOMMENDATION
--------------------
GO for founder-led web pilot and design partners.
NO-GO for App Store marketing as primary platform until mobile verdict flips.
Prioritize proof over features for 30 days.

${exportStats}
`;
}

function formatPreproductionAuditMd(reports, routes) {
  const mfc = reports.mobileFirstClass;
  const mr = reports.mobileReadiness;
  return `# Pre-Production Audit

Generated: ${new Date().toISOString()}

## Readiness assessment

| Area | Status |
|------|--------|
| Web product depth | Strong — archive-first UX, belief systems, validators |
| Mobile product | ${mfc?.verdict ?? "Unknown"} |
| Store submission | ${mr?.storeReadiness?.status ?? "FAILING"} |
| Revenue / billing | Stripe web; native IAP missing |

## Critical blockers

${(mfc?.validationFailures ?? ["See validate:mobile-primary-product"]).map((f) => `- ${f}`).join("\n")}

## Go / No-Go

- **Web founder pilot:** GO — with measurement discipline.
- **App Store as primary platform:** NO-GO — until restore, native billing, and store evidence pass.
- **Paid user acquisition:** NO-GO — until value-moment conversion proven on cohort.

## Routes reference

- Public pages: ${routes.publicRoutes.length}
- Internal dashboards: ${routes.internalRoutes.length}
`;
}

function formatMobileGapMd(reports) {
  const mfc = reports.mobileFirstClass;
  const parity = reports.parity;
  return `# Mobile Gap Report

Generated: ${new Date().toISOString()}

## Platform verdict

**${mfc?.verdict ?? "N/A"}**

${mfc?.verdictReasons?.map((r) => `- ${r}`).join("\n") ?? ""}

## Companion vs primary

| Criterion | Status |
|-----------|--------|
| Install → Record → Archive on device | Journey steps present |
| Pay without web | Blocked — Stripe external browser |
| Restore on device | Blocked — no RevenueCat / restore UI |

## Missing proof

- \`revenuecat_store_tested\`, \`restore_purchases_tested\`, \`stripe_checkout_tested\` evidence JSON
- Native push verification on physical iPhone + Android
- TestFlight / Play internal upload evidence

## Native billing gaps

- No \`purchases_flutter\` in pubspec
- Pricing opens external browser only

## Restore gaps

${mfc?.paywall?.checks?.find((c) => c.id === "restore_purchases")?.note ?? "No restore flow"}

## Push gaps

- FCM not wired; local notifications used for verification harness only

## Required actions

1. Integrate RevenueCat + restore purchases UI on Flutter.
2. Commit \`mobile/evidence/*.json\` from real device/store runs.
3. Re-run \`npm run validate:mobile-primary-product\` until verdict is PRIMARY_PLATFORM.
4. Keep web internal dashboards out of mobile router (already enforced).

## Parity snapshot

${parity?.features?.map((f) => `- **${f.label}:** ${f.status}`).join("\n") ?? "Run generate:mobile-parity-report"}
`;
}

function formatStoreSubmissionMd(reports) {
  const mr = reports.mobileReadiness;
  const items = mr?.items ?? [];
  const row = (id) => items.find((i) => i.id === id);
  return `# Store Submission Report

Generated: ${new Date().toISOString()}

## Apple readiness

| Item | Status |
|------|--------|
| iOS signing | ${row("ios_signing")?.status ?? "UNKNOWN"} |
| TestFlight | ${row("testflight")?.status ?? "UNKNOWN"} |
| Push | ${row("push_notifications")?.status ?? "FAILING"} |
| IAP / RevenueCat | ${row("revenuecat")?.status ?? "FAILING"} |

## Google readiness

| Item | Status |
|------|--------|
| Android signing | ${row("android_signing")?.status ?? "UNKNOWN"} |
| Play internal | ${row("play_store")?.status ?? "UNKNOWN"} |
| Restore | ${row("restore_purchases")?.status ?? "FAILING"} |

## Metadata readiness

- App display name ArchiveMe on iOS plist
- Privacy/terms routes on web + mobile settings
- Screenshots: **not evidenced in repo** — manual App Store Connect / Play Console work

## Subscription readiness

- Web: Stripe checkout when configured
- Mobile: browser checkout only — **not store-compliant as primary billing**

## Submission blockers

${items
  .filter((i) => i.status !== "PASSING")
  .map((i) => `- ${i.label}: ${i.status}`)
  .join("\n")}

Overall store pillar: **${mr?.storeReadiness?.status ?? "FAILING"}**
`;
}

function formatActivationValidationMd() {
  return `# Activation Validation Report

Generated: ${new Date().toISOString()}

## Funnel stages

| Stage | System | Evidence in repo |
|-------|--------|------------------|
| First belief activation | Archive belief home, 1→5 reflection ladder | archive-value-progress validators |
| Archive curiosity | Theory curiosity, discover, open loops | validate:theory-curiosity, discovery-loop |
| Archive return | Return triggers, callback learning, resurfacing | return-trigger-attribution, callback-learning |
| Attachment | archive-attachment, continuity reinforcement | validate:archive-attachment |
| Conversion | value-moment paywall, paywall-attribution | validate:value-moment-paywall |

## Evidence collected (structural)

- Local analytics + founder-test dashboards
- Auth value validation phase documentation
- Paywall attribution internal page
- North star 5-metric dashboard

## Evidence missing (requires live users)

- Cohort 4→5 reflection completion rate
- Post-blind-spot paywall CTA → paid conversion
- Week-2 return after first pattern review
- 10+ founder tests with "would pay for continuity"

## Recommendation

Run founder-test checklist on web before scaling; do not trust validator pass alone for activation proof.
`;
}

function appendBucketFiles(body, files, bytes, meta) {
  for (const rel of files) {
    const read = readFileSafe(rel);
    if (!read) continue;
    const block = formatFileBlock(rel, read.content);
    if (bytes + Buffer.byteLength(block, "utf8") > MAX_OUTPUT_BYTES) {
      body += `\n[Truncated — size cap; remaining files omitted from ${meta.file}]\n`;
      break;
    }
    body += block;
    bytes += Buffer.byteLength(block, "utf8");
  }
  return { body, bytes };
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });

  const allFiles = walkFiles(ROOT).sort();
  const skippedPaths = [];
  const includedPaths = [];

  const assignments = new Map(TXT_OUTPUTS.map((o) => [o.id, []]));
  for (const rel of allFiles) {
    const bucket = classifyApp21(rel);
    if (!bucket) {
      skippedPaths.push(rel);
      continue;
    }
    assignments.get(bucket).push(rel);
    includedPaths.push(rel);
  }

  const reports = await loadReports();
  const routes = listRoutes(allFiles);

  let validateScriptCount = 0;
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
    validateScriptCount = Object.keys(pkg.scripts ?? {}).filter((k) =>
      k.startsWith("validate:"),
    ).length;
  } catch {
    /* ignore */
  }

  const stats = {
    totalSourceFiles: allFiles.length,
    dartCount: allFiles.filter((f) => f.endsWith(".dart")).length,
    validateScriptCount,
    redactedEnvSkipped: allFiles.filter((f) => /\.env/i.test(f) && !/\.example$/i.test(f)).length,
  };

  const exportStats = {
    generatedAt: new Date().toISOString(),
    outputDir: OUT_DIR,
    txtFiles: TXT_OUTPUTS.length,
    mdFiles: MD_REPORTS.length,
    includedPathCount: includedPaths.length,
    skippedPathCount: skippedPaths.length,
    redactions:
      ".env omitted; sk_/pk_/whsec_/price_; DATABASE_URL; bearer tokens; private keys redacted",
    skippedDirs: [...SKIP_DIR_NAMES],
    lockfilesExcluded: [...SKIP_FILE_NAMES],
  };

  const generatedSections = {
    "01": generateExecutiveReview(reports, routes, stats),
    "02": generateProductArchitecture(routes),
    "03": generateArchiveEngineSummary(),
    "04": generateActivationSummary(),
    "06": generateFlutterSummary(allFiles),
    "10": "",
  };

  const outputManifest = [];

  for (const meta of TXT_OUTPUTS) {
    const files = meta.synthesisOnly && meta.id !== "02"
      ? meta.id === "01" || meta.id === "10"
        ? []
        : [...(assignments.get(meta.id) ?? [])].sort()
      : [...(assignments.get(meta.id) ?? [])].sort();

    let body = buildToc(meta, files);
    body += generatedSections[meta.id] ?? "";
    let bytes = Buffer.byteLength(body, "utf8");

    if (!meta.synthesisOnly || meta.id === "03" || meta.id === "04" || meta.id === "02") {
      const result = appendBucketFiles(body, files, bytes, meta);
      body = result.body;
      bytes = result.bytes;
    }

    if (meta.id === "10") {
      body += generateFinalAudit(routes, reports, "");
    }

    const outPath = path.join(OUT_DIR, meta.file);
    fs.writeFileSync(outPath, body, "utf8");
    const lineCount = body.split("\n").length;
    const size = fs.statSync(outPath).size;
    outputManifest.push({
      file: meta.file,
      lines: lineCount,
      size,
      sourceFiles: files.length,
    });
  }

  const summaryBlock = `
================================================================================
EXPORT SUMMARY (app21)
================================================================================
Generated: ${exportStats.generatedAt}
Output directory: ${exportStats.outputDir}

FILE COUNT
----------
TextEdit .txt files: ${exportStats.txtFiles}
Markdown reports: ${exportStats.mdFiles}
Total output files: ${exportStats.txtFiles + exportStats.mdFiles}

LINE & SIZE TOTALS
------------------
${outputManifest.map((o) => `  ${o.file}: ${o.lines.toLocaleString()} lines, ${(o.size / 1024).toFixed(1)} KB (${o.sourceFiles} source files)`).join("\n")}

AGGREGATE
---------
Total lines (txt): ${outputManifest.reduce((a, o) => a + o.lines, 0).toLocaleString()}
Total size (txt): ${(outputManifest.reduce((a, o) => a + o.size, 0) / 1024 / 1024).toFixed(2)} MB

INCLUDED PATHS: ${exportStats.includedPathCount} files from repo scan
SKIPPED PATHS: ${exportStats.skippedPathCount} (binary, non-text, or unclassified assets)
REDACTIONS: ${exportStats.redactions}
SKIPPED DIRS: ${exportStats.skippedDirs.join(", ")}
LOCKFILES EXCLUDED: ${exportStats.lockfilesExcluded.join(", ")}
.env files not exported: ${stats.redactedEnvSkipped}
Dart files in repo: ${stats.dartCount}
npm validate:* scripts: ${stats.validateScriptCount}
`;

  fs.appendFileSync(path.join(OUT_DIR, TXT_OUTPUTS[9].file), summaryBlock, "utf8");
  outputManifest[9].size = fs.statSync(path.join(OUT_DIR, TXT_OUTPUTS[9].file)).size;
  outputManifest[9].lines = fs.readFileSync(path.join(OUT_DIR, TXT_OUTPUTS[9].file), "utf8").split("\n").length;

  const mdContents = {
    "PREPRODUCTION_AUDIT.md": formatPreproductionAuditMd(reports, routes),
    "MOBILE_GAP_REPORT.md": formatMobileGapMd(reports),
    "STORE_SUBMISSION_REPORT.md": formatStoreSubmissionMd(reports),
    "ACTIVATION_VALIDATION_REPORT.md": formatActivationValidationMd(),
  };

  for (const name of MD_REPORTS) {
    const mdPath = path.join(OUT_DIR, name);
    fs.writeFileSync(mdPath, mdContents[name], "utf8");
    const size = fs.statSync(mdPath).size;
    const lines = mdContents[name].split("\n").length;
    outputManifest.push({ file: name, lines, size, sourceFiles: 0 });
  }

  console.log("\nArchiveMe app21 pre-production export complete\n");
  console.log(`Output: ${OUT_DIR}\n`);
  for (const o of outputManifest) {
    console.log(`  • ${o.file} — ${o.lines.toLocaleString()} lines, ${(o.size / 1024).toFixed(1)} KB`);
  }
  console.log(`\n${summaryBlock}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
