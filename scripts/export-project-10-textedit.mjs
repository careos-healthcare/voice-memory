#!/usr/bin/env node
/**
 * Export ArchiveMe into 10 TextEdit-friendly .txt files (no secrets).
 * Output: /Users/chiragpatel/Desktop/spp20/
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT_DIR = "/Users/chiragpatel/Desktop/spp20";

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
]);

const MAX_SINGLE_FILE_BYTES = 120_000;
const MAX_OUTPUT_BYTES = 4_500_000;

const OUTPUTS = [
  {
    id: "01",
    file: "01_PRODUCT_OVERVIEW_AND_ROUTES.txt",
    title: "Product Overview and Routes",
    description:
      "App routes, public/internal pages, product positioning, onboarding and activation path.",
  },
  {
    id: "02",
    file: "02_CORE_UI_COMPONENTS.txt",
    title: "Core UI Components",
    description:
      "Major components — homepage, memory, blind spots, discover, theories, updates, pricing/paywall.",
  },
  {
    id: "03",
    file: "03_BLIND_SPOTS_AND_PATTERN_ENGINE.txt",
    title: "Blind Spots and Pattern Engine",
    description:
      "Blind spot logic, ranking, scorecards, ingredient optimizer, experiments, follow-ups, quality review.",
  },
  {
    id: "04",
    file: "04_DISCOVER_THEORIES_NOTIFICATIONS.txt",
    title: "Discover, Theories, and Notifications",
    description:
      "Theory tracker, discover feed, evidence feed, volatility, notifications, effectiveness.",
  },
  {
    id: "05",
    file: "05_ACTIVATION_RETENTION_AND_METRICS.txt",
    title: "Activation, Retention, and Metrics",
    description:
      "Archive-belief UX, archive value deepening (worth, evidence locker, belief dossier, evidence search, loss prompt), export/evidence trail, attachment/recall, founder dashboards, activation/retention metrics.",
  },
  {
    id: "06",
    file: "06_BILLING_PAYWALL_ENTITLEMENTS.txt",
    title: "Billing, Paywall, and Entitlements",
    description:
      "Stripe billing, entitlements, pricing, value-moment paywall, subscription gates.",
  },
  {
    id: "07",
    file: "07_API_SERVER_SECURITY_AND_DATABASE.txt",
    title: "API, Server, Security, and Database",
    description:
      "API routes, guest-first auth, OpenAI cost/security hardening, database, journal/sync, health, rate limits, production env validation.",
  },
  {
    id: "08",
    file: "08_VALIDATORS_TESTS_AND_DEPLOYMENT.txt",
    title: "Validators, Tests, and Deployment",
    description:
      "Package scripts, validate scripts, e2e tests, launch/deploy checks, staging proof.",
  },
  {
    id: "09",
    file: "09_FLUTTER_DART_MOBILE_APP.txt",
    title: "Flutter / Dart Mobile App",
    description:
      "Dart sources, Flutter UI, mobile structure, iOS/Android config summaries.",
  },
  {
    id: "10",
    file: "10_COMMERCIAL_AUDIT_AND_50K_REVENUE_READINESS.txt",
    title: "Commercial Audit and £50k/month Readiness",
    description:
      "Synthesis — monetizable surfaces, vs ChatGPT, funnel, risks, honest recommendation.",
  },
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
  [
    /DATABASE_URL\s*=\s*[^\s\n#'"]+/gi,
    "DATABASE_URL=[REDACTED_DATABASE_URL]",
  ],
  [
    /(POSTGRES_URL|SUPABASE_URL|OPENAI_API_KEY|RESEND_API_KEY|STRIPE_SECRET_KEY|STRIPE_WEBHOOK_SECRET|NEXTAUTH_SECRET|AUTH_SECRET|SESSION_SECRET|CAPTURE_ATTEST_SECRET)\s*=\s*[^\s\n#'"]+/gi,
    "$1=[REDACTED]",
  ],
  [
    /"DATABASE_URL"\s*:\s*"[^"]*"/gi,
    '"DATABASE_URL":"[REDACTED_DATABASE_URL]"',
  ],
  [
    /"(POSTGRES_URL|OPENAI_API_KEY|RESEND_API_KEY|STRIPE_SECRET_KEY|STRIPE_WEBHOOK_SECRET|NEXTAUTH_SECRET)"\s*:\s*"[^"]*"/gi,
    '"$1":"[REDACTED]"',
  ],
  [/Bearer\s+[a-zA-Z0-9._-]{20,}/g, "Bearer [REDACTED_TOKEN]"],
  [/eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/g, "[REDACTED_JWT]"],
  [
    /(SESSION_SECRET|INVITE_TOKEN|MAGIC_LINK|CAPTURE_ATTEST_SECRET|EMAIL_LOGIN_SECRET)\s*=\s*[^\s\n#'"]+/gi,
    "$1=[REDACTED]",
  ],
  [/https?:\/\/[^\s"'`]*(?:token|invite|magic|session)=[^\s"'`&]+/gi,
    "https://[REDACTED_MAGIC_LINK]"],
  [/postgres(?:ql)?:\/\/[^\s"'`]+/gi, "postgresql://[REDACTED_DATABASE_URL]"],
  [/mongodb(?:\+srv)?:\/\/[^\s"'`]+/gi, "mongodb://[REDACTED_DATABASE_URL]"],
  [/-----BEGIN (?:RSA |EC )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC )?PRIVATE KEY-----/g,
    "[REDACTED_PRIVATE_KEY]"],
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
  if (name === "build" && /apps\/mobile\/(android|ios)\//.test(parentRel)) {
    return true;
  }
  if (name === "gradle" && parentRel.includes("android/.gradle")) return true;
  return false;
}

function isTextFile(relPath) {
  const base = path.basename(relPath);
  if (SKIP_FILE_NAMES.has(base)) return false;
  if (/\.env(\.|$)/i.test(relPath) && !/\.example$/i.test(relPath)) return false;
  const ext = path.extname(relPath).toLowerCase();
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
    if (entry.name === "export-project-10-textedit.mjs" && base === "scripts") continue;
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

/** Assign each repo file to exactly one output bucket (first match wins). */
function classifyFile(rel) {
  const p = rel.replace(/\\/g, "/");

  if (/\.dart$/i.test(p)) return "09";
  if (p.startsWith("apps/mobile/ios/")) {
    if (/\.(png|jpg|jpeg|gif|ico|webp|storyboard|xcassets)$/i.test(p)) return null;
    if (/\.(plist|gradle|kts|xml|properties|swift|kt|md|yaml|yml|json)$/i.test(p)) return "09";
    return null;
  }
  if (p.startsWith("apps/mobile/android/")) {
    if (/\.(png|jpg|jpeg|gif|ico|webp)$/i.test(p)) return null;
    if (
      /\.(gradle|kts|xml|properties|kt|md|yaml|yml|json|pro)$/i.test(p) ||
      p.endsWith("AndroidManifest.xml")
    ) {
      return "09";
    }
    return null;
  }
  if (p === "apps/mobile/pubspec.yaml") return "09";

  if (p.startsWith("scripts/") || p.startsWith("e2e/") || /^playwright/i.test(p)) return "08";
  if (p === "package.json") return "08";

  if (
    p.startsWith("apps/api/app/api/") ||
    p.startsWith("packages/shared/lib/server/") ||
    p.startsWith("packages/shared/lib/auth/") ||
    p.startsWith("apps/web/components/auth/") ||
    p.startsWith("packages/shared/types/auth")
  ) {
    return "07";
  }
  if (
    p.startsWith("packages/shared/lib/persistence/") ||
    p.startsWith("packages/shared/lib/proof/") ||
    p.startsWith("packages/shared/lib/reliability/")
  ) {
    return "07";
  }

  if (
    p.startsWith("packages/shared/lib/billing/") ||
    p.startsWith("packages/shared/lib/entitlement/") ||
    p === "packages/shared/lib/subscription.ts" ||
    p.startsWith("packages/shared/lib/monetization/") ||
    p.startsWith("apps/web/components/billing/") ||
    p.startsWith("apps/web/app/pricing/")
  ) {
    return "06";
  }

  if (
    p.startsWith("packages/shared/lib/blind-spots/") ||
    p.startsWith("apps/web/components/blind-spots/") ||
    /^types\/blind-spot/i.test(p) ||
    p.startsWith("packages/shared/lib/pattern-detection/") ||
    p.startsWith("packages/shared/lib/insights/insight-ingredient") ||
    p.startsWith("packages/shared/lib/insights/insight-scorecard") ||
    p.startsWith("packages/shared/lib/insights/self-recognition")
  ) {
    return "03";
  }

  if (
    p.startsWith("packages/shared/lib/discover/") ||
    p.startsWith("packages/shared/lib/theories/") ||
    p.startsWith("apps/web/components/discover/") ||
    p.startsWith("apps/web/components/theories/") ||
    /^types\/theory/i.test(p) ||
    /^types\/evidence-feed/i.test(p)
  ) {
    return "04";
  }

  if (
    p.startsWith("apps/web/app/archive-belief/") ||
    p.startsWith("apps/web/app/export/") ||
    p.startsWith("apps/web/app/account/") ||
    p.startsWith("apps/web/app/internal/archive-belief") ||
    p.startsWith("apps/web/app/internal/auth-value") ||
    p.startsWith("apps/web/components/archive/") ||
    p.startsWith("packages/shared/lib/archive/") ||
    p.startsWith("packages/shared/types/archive-worth") ||
    p.startsWith("packages/shared/types/evidence-locker") ||
    p.startsWith("packages/shared/types/belief-dossier") ||
    p.startsWith("packages/shared/types/evidence-search") ||
    p.startsWith("packages/shared/lib/memory-export") ||
    p === "packages/shared/lib/memory-export.ts" ||
    p.startsWith("packages/shared/lib/product/archive-value") ||
    p.startsWith("packages/shared/lib/product/activation") ||
    p.startsWith("packages/shared/lib/product/first-blind-spot") ||
    p.startsWith("packages/shared/lib/product/pattern-activation") ||
    p.startsWith("packages/shared/lib/product/product-clarity") ||
    p.startsWith("packages/shared/lib/product/returning-home") ||
    p.startsWith("packages/shared/lib/founder-test/") ||
    p.startsWith("packages/shared/lib/breakthrough/") ||
    p.startsWith("packages/shared/lib/retention/") ||
    p.startsWith("packages/shared/lib/onboarding/") ||
    p.startsWith("apps/web/components/product/") ||
    p.startsWith("apps/web/components/internal/") ||
    p.startsWith("apps/web/components/retention/") ||
    p.startsWith("apps/web/app/internal/retention") ||
    p.startsWith("apps/web/app/internal/founder-test") ||
    p.startsWith("apps/web/app/debug/retention") ||
    p.startsWith("packages/shared/lib/insights/insight-outcome") ||
    /^types\/(retention|founder-test|archive-value|onboarding)/i.test(p)
  ) {
    return "05";
  }

  if (
    p === "apps/web/app/page.tsx" ||
    p.startsWith("apps/web/app/memory/") ||
    p.startsWith("apps/web/app/discover/") ||
    p.startsWith("apps/web/app/blind-spots/") ||
    p.startsWith("apps/web/app/theories/") ||
    p.startsWith("apps/web/app/updates/") ||
    p.startsWith("apps/web/app/record/") ||
    p.startsWith("apps/web/app/entry/") ||
    p.startsWith("apps/web/app/welcome/") ||
    p.startsWith("apps/web/components/Recorder.tsx") ||
    p.startsWith("apps/web/components/ActivationOnboarding") ||
    p.startsWith("apps/web/components/memory/") ||
    p.startsWith("apps/web/components/layout/") ||
    p.startsWith("apps/web/components/motion/") ||
    p.startsWith("apps/web/components/ui/") ||
    p.startsWith("apps/web/components/system/") ||
    p.startsWith("apps/web/components/SiteHeader") ||
    p.startsWith("packages/shared/lib/product-copy") ||
    p.startsWith("packages/shared/lib/tester-onboarding") ||
    p.startsWith("packages/shared/lib/activation-guidance")
  ) {
    return "02";
  }

  if (
    p.startsWith("apps/web/app/") &&
    (p.endsWith("/page.tsx") ||
      p.endsWith("/layout.tsx") ||
      p.endsWith("/loading.tsx") ||
      p.endsWith("/route.ts"))
  ) {
    return "01";
  }
  if (
    p.startsWith("packages/shared/lib/product/") ||
    p.startsWith("packages/shared/lib/marketing/") ||
    p === "AGENTS.md" ||
    p === "CLAUDE.md" ||
    p.startsWith("docs/")
  ) {
    return "01";
  }

  if (p.startsWith("apps/web/components/") && !p.startsWith("apps/web/components/internal/")) return "02";
  if (p.startsWith("packages/shared/lib/sync/")) return "07";
  if (p.startsWith("apps/api/app/api/")) return "07";

  if (p.startsWith("packages/shared/types/")) {
    if (/blind-spot/i.test(p)) return "03";
    if (/theory|evidence/i.test(p)) return "04";
    if (/entitlement|monetization/i.test(p)) return "06";
    if (/organic-referral|archive-attachment|paywall|retention|founder|onboarding/i.test(p)) {
      return "05";
    }
    return "02";
  }

  if (p.startsWith("packages/shared/lib/refinement/") || p.startsWith("packages/shared/lib/resurfacing/")) return "05";
  if (p.startsWith("packages/shared/lib/insights/")) return "03";
  if (p.startsWith("packages/shared/lib/storage.ts") || p === "packages/shared/lib/storage.ts") return "07";
  if (p.startsWith("packages/shared/lib/local-analytics")) return "05";
  if (p.startsWith("packages/shared/lib/internal/")) return "05";
  if (p.startsWith("packages/shared/lib/metrics/")) return "05";
  if (p.startsWith("packages/shared/lib/")) return "02";
  if (p.startsWith("apps/web/app/")) return "01";
  if (p.startsWith("apps/web/components/")) return "02";
  if (p.startsWith("public/")) return "02";
  if (p.startsWith("supabase/")) return "07";
  if (/^(middleware|next\.config|tsconfig|tailwind|postcss|vercel|capacitor|components\.json)/i.test(p)) {
    return "08";
  }

  return "01";
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
  const raw = fs.readFileSync(full, "utf8");
  return { truncated: false, content: redactContent(raw, rel) };
}

function formatFileBlock(rel, content) {
  const sep = "=".repeat(72);
  return `${sep}\nFILE: ${rel}\n${sep}\n\n${content}\n\n`;
}

function buildToc(bucketId, files) {
  const meta = OUTPUTS.find((o) => o.id === bucketId);
  const lines = [
    "TABLE OF CONTENTS",
    "=================",
    `Export: ${meta.file}`,
    `Title: ${meta.title}`,
    `Generated: ${new Date().toISOString()}`,
    `Root: ${ROOT}`,
    "",
    meta.description,
    "",
    `Files included (${files.length}):`,
    "",
  ];
  files.forEach((f, i) => {
    lines.push(`${String(i + 1).padStart(4, " ")}. ${f}`);
  });
  lines.push("", "—".repeat(72), "");
  return lines.join("\n");
}

function listRoutes(files) {
  const routes = files
    .filter((f) => /^app\/.+\/page\.tsx$/.test(f))
    .map((f) => "/" + f.replace(/^app\//, "").replace(/\/page\.tsx$/, "").replace(/\/index$/, ""))
    .sort();
  const publicRoutes = routes.filter((r) => !r.startsWith("/internal") && !r.startsWith("/debug"));
  const internalRoutes = routes.filter((r) => r.startsWith("/internal") || r.startsWith("/debug"));
  return { routes, publicRoutes, internalRoutes };
}

function generateCommercialAudit(allFiles, assignments) {
  const routes = listRoutes(allFiles);
  const validateScripts = allFiles.filter((f) => f.startsWith("scripts/validate"));
  const dartFiles = allFiles.filter((f) => f.endsWith(".dart"));
  const billingFiles = assignments.get("06") ?? [];
  const blindSpotFiles = assignments.get("03") ?? [];
  const discoverFiles = assignments.get("04") ?? [];

  let pkgScripts = 0;
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
    pkgScripts = Object.keys(pkg.scripts ?? {}).filter((k) => k.startsWith("validate:")).length;
  } catch {
    pkgScripts = 0;
  }

  return `
================================================================================
FILE: COMMERCIAL_AUDIT_SYNTHESIS (generated — not source code)
================================================================================

VOICEMEMORY — COMMERCIAL AUDIT & £50,000/MONTH READINESS
Generated: ${new Date().toISOString()}

EXECUTIVE SUMMARY
-----------------
ArchiveMe is a local-first, voice reflection archive with pattern/blind-spot discovery,
theory tracking, and value-moment monetization. The web app is feature-rich with extensive
founder instrumentation; revenue readiness depends on proving activation (5 reflections →
first pattern review) and converting after demonstrated value, not before.

WHAT EXISTS (INVENTORY)
-----------------------
• Public routes: ${routes.publicRoutes.length} pages
• Internal/debug routes: ${routes.internalRoutes.length} pages
• npm validate:* scripts: ~${pkgScripts}
• Blind-spot / pattern modules: ${blindSpotFiles.length} files
• Discover / theory modules: ${discoverFiles.length} files
• Billing / entitlement modules: ${billingFiles.length} files
• Flutter Dart files: ${dartFiles.length}
• Validator scripts on disk: ${validateScripts.length}

STRONGEST MONETIZABLE SURFACES
------------------------------
1. Value-moment paywall (post first blind spot + post first discover) — continuity framing.
2. Pro tier (£9.99/month positioning): ongoing theory changes, full archive continuity,
   pattern softening/returning, export.
3. Archive value progression (1→5 reflections) — makes each recording feel accretive.
4. Blind spot review at 5+ reflections — high-trust “proof” moment before paywall.
5. Discover/theory change feed — differentiated vs ChatGPT (longitudinal, not single-session).

WEAKNESSES VS CHATGPT
-----------------------
• ChatGPT wins same-day thinking, drafting, and general reasoning with zero setup.
• ArchiveMe requires 5 reflections before full pattern review — cold-start friction.
• Mobile Flutter app exists but web is the mature surface; cross-platform parity unproven.
• Live Stripe/billing depends on env — fail-closed when not configured.
• No network-effect moat; value is private archive depth (good for retention, harder for PLG).

ACTIVATION FUNNEL (AS BUILT)
----------------------------
1. Record reflection (never paywalled pre-5).
2. Archive value ladder (1=data point … 5=pattern review unlocked).
3. Discover / blind spots first visits free.
4. Post-value paywalls on revisit (blind spot @5+, discover on 2nd visit).
5. Archive continuity gate after both paywall moments acknowledged.

RETENTION RISKS
---------------
• Users who stop at 1–2 reflections never see blind spot proof.
• Paywall only works if first blind spot feels “surprising” or “uncomfortably accurate.”
• Theory/discover value requires baseline visit + return — second-session dependency.
• Founder preview / dev bypass can hide paywall bugs in dogfooding.
• Large internal dashboard surface — risk of optimizing metrics over user feeling.

WHAT MUST BE PROVEN FOR ~£50K/MONTH
-----------------------------------
At £9.99/month ≈ 5,000 paying subscribers (before fees/tax).

Must prove:
• Conversion after value moment: CTA click → paid (track value_moment_paywall_* events).
• 4→5 reflection completion rate (activation bottleneck metrics).
• Week-2 return after first blind spot (retention discovery, founder test checklist).
• Paid churn < 8%/month once billing live.
• CAC or organic loop that can supply ~hundreds of new activated users/month.

BRUTALLY HONEST RECOMMENDATION
------------------------------
Ship candidate: YES for founder-led pilot / design partners — NO for broad paid ads until:
  (a) 10+ founder tests complete checklist with “would pay for continuity” signal,
  (b) Stripe live on staging with end-to-end entitlement sync proven,
  (c) 4→5 reflection rate and post-blind-spot paywall CTA rate measured > baseline.

Priority order:
1. Measure 4→5 and first blind spot reaction mix (surprising / uncomfortably accurate).
2. Run value-moment paywall A/B on copy only — do not add features before conversion proof.
3. Tighten returning-user discover diff (theory changes) — this is the Pro promise.
4. Flutter mobile: parity for record + sync only; defer discover/blind spot on mobile.
5. Do not expand analysis engines — deepen proof and paywall timing.

MEASUREMENT LAYER (recent)
--------------------------
• Archive value deepening: worth statement, evidence locker, belief dossier, evidence search,
  loss aversion prompt, evidence-trail export bundle
• Guest-first auth: record without email; protect archive at value moments
• OpenAI cost/security: daily spend caps, budget guard, kill switch
• Archive attachment, organic referral, paywall attribution, return-trigger attribution
• Auth value validation phase (quotes over local conversion metrics until 10+ users)

Verdict: Product depth exceeds typical pre-revenue startups; commercial risk is activation and
conversion timing, not missing features. £50k/month is achievable only with disciplined
proof of paywall-after-value conversion, not with more dashboards or engines.

REDACTION NOTICE
----------------
All .env files omitted. Stripe/OpenAI/Resend keys, webhook secrets, DATABASE_URL, bearer tokens,
and private keys redacted as prefix_[REDACTED] or [REDACTED_DATABASE_URL] in exported source.

PUBLIC ROUTES (reference)
-------------------------
${routes.publicRoutes.map((r) => `• ${r}`).join("\n")}

INTERNAL ROUTES (reference)
---------------------------
${routes.internalRoutes.slice(0, 40).map((r) => `• ${r}`).join("\n")}
${routes.internalRoutes.length > 40 ? `• … and ${routes.internalRoutes.length - 40} more` : ""}

`;
}

function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });

  const allFiles = walkFiles(ROOT).sort();
  const assignments = new Map(OUTPUTS.map((o) => [o.id, []]));

  for (const rel of allFiles) {
    const bucket = classifyFile(rel);
    if (!bucket) continue;
    assignments.get(bucket).push(rel);
  }

  const stats = {
    redactedEnvSkipped: allFiles.filter((f) => /\.env/i.test(f) && !/\.example$/i.test(f))
      .length,
    dartIncluded: 0,
    outputs: [],
  };

  for (const out of OUTPUTS) {
    const files = [...(assignments.get(out.id) ?? [])].sort();
    if (out.id === "10") {
      files.length = 0;
    }

    let body = buildToc(out.id, files);
    let bytes = Buffer.byteLength(body, "utf8");

    if (out.id === "10") {
      body += generateCommercialAudit(allFiles, assignments);
      bytes = Buffer.byteLength(body, "utf8");
    } else {
      for (const rel of files) {
        const read = readFileSafe(rel);
        if (!read) continue;
        const block = formatFileBlock(rel, read.content);
        if (bytes + Buffer.byteLength(block, "utf8") > MAX_OUTPUT_BYTES) {
          body += `\n[Truncated — output size cap reached; remaining files omitted from ${out.file}]\n`;
          break;
        }
        body += block;
        bytes += Buffer.byteLength(block, "utf8");
        if (out.id === "09" && rel.endsWith(".dart")) stats.dartIncluded += 1;
      }
    }

    const outPath = path.join(OUT_DIR, out.file);
    fs.writeFileSync(outPath, body, "utf8");
    const lineCount = body.split("\n").length;
    const size = fs.statSync(outPath).size;
    stats.outputs.push({
      file: out.file,
      path: outPath,
      lines: lineCount,
      size,
      files: out.id === "10" ? 1 : files.length,
    });
  }

  // Route index appendix for file 01
  const file01 = path.join(OUT_DIR, OUTPUTS[0].file);
  const routeIndex = listRoutes(allFiles);
  const appendix = `
================================================================================
FILE: ROUTE_INDEX_GENERATED
================================================================================

PUBLIC ROUTES (${routeIndex.publicRoutes.length})
${routeIndex.publicRoutes.map((r) => `  ${r}`).join("\n")}

INTERNAL / DEBUG ROUTES (${routeIndex.internalRoutes.length})
${routeIndex.internalRoutes.map((r) => `  ${r}`).join("\n")}

API ROUTES (app/api)
${allFiles
  .filter((f) => f.startsWith("apps/api/app/api/") && f.endsWith("/route.ts"))
  .map((f) => `  /api/${f.replace(/^app\/api\//, "").replace(/\/route\.ts$/, "")}`)
  .join("\n")}
`;
  fs.appendFileSync(file01, appendix, "utf8");
  stats.outputs[0].size = fs.statSync(file01).size;
  stats.outputs[0].lines = fs.readFileSync(file01, "utf8").split("\n").length;

  console.log("\nArchiveMe 10-part TextEdit export complete\n");
  console.log(`Output directory: ${OUT_DIR}\n`);
  console.log("Created files:");
  let totalSize = 0;
  let totalLines = 0;
  for (const o of stats.outputs) {
    console.log(`  • ${o.file}`);
    console.log(`      ~${o.lines.toLocaleString()} lines, ${(o.size / 1024).toFixed(1)} KB, ${o.files} source files`);
    totalSize += o.size;
    totalLines += o.lines;
  }
  console.log(`\nTotal: ~${totalLines.toLocaleString()} lines, ${(totalSize / 1024 / 1024).toFixed(2)} MB`);
  const manifest = {
    generatedAt: new Date().toISOString(),
    root: ROOT,
    outputDir: OUT_DIR,
    parts: stats.outputs,
    totalSourceFiles: allFiles.length,
    redaction:
      ".env omitted; sk_/pk_/whsec_/price_ → prefix_[REDACTED]; DATABASE_URL → [REDACTED_DATABASE_URL]",
    skippedDirs: [...SKIP_DIR_NAMES],
  };
  console.log(`\nSecrets: .env* omitted; sk_/pk_/whsec_/price_/DB URLs/tokens/private keys redacted.`);
  console.log(`Parts: exactly ${OUTPUTS.length} .txt files in ${OUT_DIR}`);
  console.log(`Dart files included in 09: ${stats.dartIncluded} (of ${allFiles.filter((f) => f.endsWith(".dart")).length} in repo)`);
  console.log(`Env files skipped (not exported): ${stats.redactedEnvSkipped}`);
}

main();
