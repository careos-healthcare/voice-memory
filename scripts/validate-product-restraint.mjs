#!/usr/bin/env node
/**
 * Unified product restraint validation — combines 18 former single-purpose scripts.
 * Run all: npm run validate:restraint
 * Run one:  RESTRAINT_CHECK=quiet-copy npm run validate:restraint
 */
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function formatViolation(v) {
  const filePath = v.filePath ?? v.file;
  const lineNo = v.lineNo ?? (typeof v.line === "number" ? v.line : 0);
  if (filePath && typeof filePath === "string") {
    const rel = path.relative(ROOT, filePath);
    const loc = lineNo > 0 ? `${rel}:${lineNo}` : rel;
    const label = v.label ?? v.word ?? v.rule ?? "violation";
    const text =
      v.text ??
      (typeof v.line === "string" ? v.line : "") ??
      v.detail ??
      "";
    return `${loc} [${label}] ${text}`.trim();
  }
  return String(v);
}

/**
 * Self-expiring deferral for an invariant whose subject was retired to
 * `apps/web/archived-*`.
 *
 * Production web is marketing, legal, support and beta; `apps/mobile` is the
 * consumer product. Assertions about retired consumer components cannot pass,
 * and repointing them at the archived copies would validate code that no
 * longer ships. Deferring is only honest if the deferral cannot rot, so this
 * fails in both directions:
 *
 *  - the live path exists again — the surface came back, the deferral is
 *    stale, and the assertion must be reinstated against it;
 *  - the archived copy is gone — the content is genuinely gone, so the
 *    validator is asserting nothing and should be deleted outright.
 *
 * Returns true while the deferral genuinely holds, meaning the caller should
 * skip the retired assertion. A deferral that only warned would be the same
 * vacuous pattern this repo has already been bitten by.
 */
function archivedCandidatesFor(livePath) {
  const candidates = [];
  if (livePath.startsWith("apps/web/components/")) {
    const rest = livePath.slice("apps/web/components/".length);
    candidates.push(`apps/web/archived-components/_archived/${rest}`);
  }
  if (livePath.startsWith("apps/web/app/internal/")) {
    const rest = livePath.slice("apps/web/app/internal/".length);
    candidates.push(`apps/web/archived-consumer-routes/internal/${rest}`);
  }
  if (livePath.startsWith("apps/web/app/")) {
    const rest = livePath.slice("apps/web/app/".length);
    candidates.push(`apps/web/archived-consumer-routes/_archived/${rest}`);
    candidates.push(`apps/web/archived-consumer-routes/${rest}`);
  }
  return candidates;
}

function deferRetiredWebSurface(livePath, fail, explicitArchivedPath) {
  if (fs.existsSync(path.join(ROOT, livePath))) {
    fail(
      `${livePath} exists again — this check was deferred while the consumer ` +
        `web surface was retired. Remove the deferral and assert against it.`,
    );
    return false;
  }

  const candidates = explicitArchivedPath
    ? [explicitArchivedPath]
    : archivedCandidatesFor(livePath);
  const archived = candidates.find((c) => fs.existsSync(path.join(ROOT, c)));

  if (!archived) {
    fail(
      `${livePath} is retired and no archived copy remains (looked in ` +
        `${candidates.join(", ") || "no known archive location"}) — nothing is ` +
        `being validated. Delete this check instead of leaving it deferred.`,
    );
    return false;
  }

  return true;
}

/**
 * Splits a REQUIRED_FILES list into the paths still worth asserting and the
 * retired consumer-web paths, deferring each retired one under the
 * both-directions rule above.
 */
function partitionRetiredWebRequirements(required, fail) {
  return required.filter((rel) => {
    if (!rel.startsWith("apps/web/")) return true;
    if (fs.existsSync(path.join(ROOT, rel))) return true;
    return !deferRetiredWebSurface(rel, fail);
  });
}

const CHECKS = [
  { name: "quiet-copy", run: checkQuietCopy },
  { name: "permanence", run: checkPermanence },
  { name: "validation-ops", run: checkValidationOps },
  { name: "pilot", run: checkPilot },
  { name: "integrity", run: checkIntegrity },
  { name: "individuality", run: checkIndividuality },
  { name: "sacredness", run: checkSacredness },
  { name: "personalization", run: checkPersonalization },
  { name: "territories", run: checkTerritories },
  { name: "atmosphere", run: checkAtmosphere },
  { name: "compounding", run: checkCompounding },
  { name: "install-prompt-restraint", run: checkInstallPromptRestraint },
  { name: "pwa-restraint", run: checkPwaRestraint },
  { name: "vulnerability-timing", run: checkVulnerabilityTiming },
  { name: "product-simplification", run: checkProductSimplification },
  { name: "restraint", run: checkRestraint },
  { name: "archive-silence", run: checkArchiveSilence },
  { name: "offline-recording-copy", run: checkOfflineRecordingCopy },
];

async function main() {
  const only = process.env.RESTRAINT_CHECK?.trim();
  const selected = only ? CHECKS.filter((c) => c.name === only) : CHECKS;
  if (only && selected.length === 0) {
    console.error(`Unknown RESTRAINT_CHECK="${only}". Valid: ${CHECKS.map((c) => c.name).join(", ")}`);
    process.exit(1);
  }

  let failed = false;
  for (const check of selected) {
    const failures = await check.run();
    if (failures.length > 0) {
      failed = true;
      console.error(`\n[${check.name}] failed — ${failures.length} issue(s):`);
      for (const f of failures.slice(0, 40)) console.error(`  ${f}`);
      if (failures.length > 40) console.error(`  … and ${failures.length - 40} more`);
    } else {
      console.log(`[${check.name}] passed`);
    }
  }

  if (failed) {
    console.error("\nvalidate:restraint failed");
    process.exit(1);
  }
  console.log(`validate:restraint passed (${selected.length} check(s))`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

async function checkQuietCopy() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const SCAN_DIRS = ["apps/web/app", "apps/web/components", "packages/shared/lib"];
    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      `${path.sep}api${path.sep}`,
      "apps/web/app/safety",
      "apps/web/app/privacy",
      "apps/web/app/terms",
      "apps/web/app/contact",
      "packages/shared/lib/trust-copy.ts",
      "packages/shared/lib/marketing/",
      "packages/shared/lib/social-proof/",
      "packages/shared/lib/sharing/",
      "packages/shared/lib/memory/memory-compounding.ts",
      "packages/shared/lib/memory/slow-realizations.ts",
      "packages/shared/lib/refinement/revisit-sequencing.ts",
      "packages/shared/lib/refinement/durable-callbacks.ts",
      "packages/shared/lib/patterns/usefulness-filter.ts",
      "packages/shared/lib/patterns/note-limits.ts",
      "packages/shared/lib/patterns/changes.ts",
      "packages/shared/lib/patterns/calmness.ts",
      "packages/shared/lib/patterns/continuity-engine.ts",
      "packages/shared/lib/patterns/pattern-engine.ts",
      "packages/shared/lib/observation-language.ts",
      "packages/shared/lib/weekly-intelligence.ts",
      "packages/shared/lib/memory/resurfacing.ts",
      "packages/shared/lib/memory/time-memory.ts",
      "packages/shared/lib/memory/revisitation.ts",
      "packages/shared/lib/memory/change-moments.ts",
      "packages/shared/lib/memory/recovery-memory.ts",
      "packages/shared/lib/memory/familiarity.ts",
      "packages/shared/lib/memory/language-fingerprint.ts",
      "packages/shared/lib/memory/rhythm-memory.ts",
      "packages/shared/lib/memory/familiarity-resurfacing.ts",
      "packages/shared/lib/memory/resurfacing-priority.ts",
      "packages/shared/lib/memory/living-resurfacing.ts",
      "packages/shared/lib/memory/delayed-payoff.ts",
      "packages/shared/lib/memory/voice-identity.ts",
      "packages/shared/lib/memory/emotional-chapters.ts",
      "packages/shared/lib/memory/emotional-weight.ts",
      "packages/shared/lib/memory/archive-growth.ts",
      "packages/shared/lib/conversation/conversation-continuity.ts",
      "packages/shared/lib/conversation/followup-prompts.ts",
      "packages/shared/lib/conversation/continuation-loops.ts",
      "packages/shared/lib/sync/",
      "packages/shared/lib/archive/",
      "packages/shared/lib/research/",
      "packages/shared/lib/sync/",
      "packages/shared/lib/reliability/",
      "packages/shared/lib/server/",
      "apps/web/app/account/",
      "packages/shared/lib/conversation/conversation-continuity.ts",
      "packages/shared/lib/conversation/voice-playback-continuity.ts",
      "packages/shared/lib/memory/memory-reminders.ts",
      "packages/shared/lib/memory/conversation-threads.ts",
      "packages/shared/lib/memory/seasons.ts",
      "packages/shared/lib/memory/relationship-continuity.ts",
      "packages/shared/lib/memory/milestones.ts",
      "packages/shared/lib/memory/shared-moments.ts",
      "packages/shared/lib/memory/continuity-depth.ts",
      "packages/shared/lib/reflection-bookmarks.ts",
      "packages/shared/lib/listening-mode.ts",
      "packages/shared/lib/pending-reflection.ts",
      "packages/shared/lib/activation-guidance.ts",
      "packages/shared/lib/reflection-goal.ts",
      "packages/shared/lib/refinement/callback-tuning.ts",
      "packages/shared/lib/refinement/emotional-timing.ts",
      "packages/shared/lib/refinement/revisit-experience.ts",
      "packages/shared/lib/refinement/memory-hierarchy.ts",
      "packages/shared/lib/refinement/knows-me-moments.ts",
      "packages/shared/lib/refinement/silence-calibration.ts",
      "packages/shared/lib/refinement/revisit-worth.ts",
      "packages/shared/lib/refinement/archive-gravity.ts",
      "packages/shared/lib/refinement/revisit-rhythm.ts",
      "packages/shared/lib/retention/retention-loops.ts",
      "packages/shared/lib/retention/gentle-return-prompts.ts",
      "packages/shared/lib/retention/pause-moments.ts",
      "packages/shared/lib/retention/moat-metrics.ts",
      "packages/shared/lib/refinement/callback-wording.ts",
      "packages/shared/lib/refinement/false-positive-suppression.ts",
      "packages/shared/lib/refinement/quiet-presentation.ts",
      "apps/web/components/navigation/RevisitEntryLink.tsx",
      "packages/shared/lib/debug/callback-quality-score.ts",
      "packages/shared/lib/debug/callback-source-map.ts",
      "packages/shared/lib/debug/callback-review-export.ts",
      "apps/web/components/InsightCard.tsx",
      "apps/web/components/InsightCardStatus.tsx",
      "apps/web/components/patterns/AvoidanceCard.tsx",
      "apps/web/components/patterns/CalmUnderstandingCard.tsx",
      "apps/web/components/patterns/ContradictionContinuityCard.tsx",
      "apps/web/components/patterns/LongitudinalContinuityCard.tsx",
      "apps/web/components/patterns/PatternInsightCard.tsx",
      "apps/web/components/patterns/ThenVsNowCard.tsx",
      "apps/web/components/patterns/WhatChangedCard.tsx",
      "packages/shared/lib/insights/",
      "apps/web/components/insights/",
    ];

    const BANNED = [
      { re: /\bpattern engine\b/i, label: "pattern engine" },
      { re: /\bemotional intelligence\b/i, label: "emotional intelligence" },
      { re: /\bpsychological\b/i, label: "psychological" },
      { re: /\btherapy-style\b/i, label: "therapy-style" },
      { re: /\bdiagnostic\b/i, label: "diagnostic" },
      { re: /\bconfidence score\b/i, label: "confidence score" },
      { re: /\binsight generated\b/i, label: "insight generated" },
      { re: /\bsignal detected\b/i, label: "signal detected" },
      { re: /\banalysis dashboard\b/i, label: "analysis dashboard" },
    ];

    const CONTEXT_BANNED = [
      { re: /\banalysis\b/i, label: "analysis" },
      { re: /\bdetected\b/i, label: "detected" },
      { re: /\bconfidence\b/i, label: "confidence" },
      { re: /\binsight\b/i, label: "insight" },
    ];

    const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

    function shouldSkip(filePath) {
      const rel = path.relative(ROOT, filePath);
      return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
    }

    function walk(dir, out = []) {
      if (!fs.existsSync(dir)) return out;
      for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (shouldSkip(full)) continue;
        const stat = fs.statSync(full);
        if (stat.isDirectory()) walk(full, out);
        else if (EXT.has(path.extname(name))) out.push(full);
      }
      return out;
    }

    function checkLine(line, filePath, lineNo, violations) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("//") || trimmed.startsWith("*")) return;
      if (trimmed.includes("validate:quiet-copy")) return;
      if (trimmed.includes("validate:restraint")) return;

      for (const { re, label } of BANNED) {
        if (re.test(line)) {
          violations.push({ filePath, lineNo, word: label, line: trimmed.slice(0, 120) });
        }
      }

      const isUserFacing =
        filePath.includes(`${path.sep}app${path.sep}`) ||
        filePath.includes(`${path.sep}components${path.sep}`);
      if (isUserFacing) {
        for (const { re, label } of CONTEXT_BANNED) {
          if (re.test(line)) {
            violations.push({ filePath, lineNo, word: label, line: trimmed.slice(0, 120) });
          }
        }
      }
    }

    const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
    const violations = [];

    for (const file of files) {
      const content = fs.readFileSync(file, "utf8");
      content.split("\n").forEach((line, i) => checkLine(line, file, i + 1, violations));
    }


    for (const v of violations) fail(formatViolation(v));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkPermanence() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const SCAN_DIRS = ["apps/web/app", "apps/web/components", "packages/shared/lib"];

    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      `${path.sep}api${path.sep}`,
      "packages/shared/lib/archive/life-periods.ts",
      "packages/shared/lib/archive/archive-landmarks.ts",
      "packages/shared/lib/archive/future-continuity.ts",
      "packages/shared/lib/archive/archive-guarantees.ts",
      "packages/shared/lib/refinement/permanent-callbacks.ts",
      "packages/shared/lib/debug/future-archive-review.ts",
      "packages/shared/lib/debug/archive-permanence-review.ts",
      "apps/web/components/ui/badge.tsx",
      "scripts/",
    ];

    const FORBIDDEN_PERMANENCE_PHRASES = [
      { re: /\bmost important reflection\b/i, label: "most important reflection" },
      { re: /\btop memory\b/i, label: "top memory" },
      { re: /\bphase 1\b/i, label: "phase 1" },
      { re: /\bgrowth era\b/i, label: "growth era" },
      { re: /\bachievement\b/i, label: "achievement" },
      { re: /\bbadge earned\b/i, label: "badge earned" },
      { re: /\bstreak\b/i, label: "streak" },
      { re: /\blevel up\b/i, label: "level up" },
      { re: /\bprogress score\b/i, label: "progress score" },
      { re: /\barchive score\b/i, label: "archive score" },
      { re: /\bdaily habit\b/i, label: "daily habit" },
      { re: /\bproductivity\b/i, label: "productivity" },
      { re: /\bgamified\b/i, label: "gamified" },
      { re: /\bmanipulative\b/i, label: "manipulative" },
      { re: /\bhealing journey\b/i, label: "healing journey" },
      { re: /\bbest self\b/i, label: "best self" },
      { re: /\brank(ed|ing)?\b/i, label: "ranking" },
      { re: /\bmilestone unlocked\b/i, label: "milestone unlocked" },
    ];

    const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

    function shouldSkip(filePath) {
      const rel = path.relative(ROOT, filePath);
      return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
    }

    function walk(dir, out = []) {
      if (!fs.existsSync(dir)) return out;
      for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (shouldSkip(full)) continue;
        const stat = fs.statSync(full);
        if (stat.isDirectory()) walk(full, out);
        else if (EXT.has(path.extname(name))) out.push(full);
      }
      return out;
    }

    function isCommentLine(trimmed) {
      return (
        trimmed.startsWith("//") ||
        trimmed.startsWith("*") ||
        trimmed.startsWith("/*") ||
        trimmed.endsWith("*/")
      );
    }

    function isValidationScriptLine(trimmed) {
      return (
        trimmed.includes("validate:permanence") ||
        trimmed.includes("validate-permanence-restraint")
      );
    }

    function isAllowedStreakContext(line) {
      return /\b(?:no|not a)\s+streak\b/i.test(line);
    }

    function isAllowedRankingContext(line) {
      return /\b(?:no|never|without)\s+rank/i.test(line) || /FORBIDDEN.*rank/i.test(line);
    }

    const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
    const violations = [];

    for (const file of files) {
      const isUserFacing =
        (file.includes(`${path.sep}app${path.sep}`) &&
          file.endsWith("page.tsx") &&
          !file.includes(`${path.sep}debug${path.sep}`)) ||
        (file.includes(`${path.sep}components${path.sep}`) &&
          !file.includes(`${path.sep}debug${path.sep}`));

      if (!isUserFacing) continue;

      const content = fs.readFileSync(file, "utf8");
      content.split("\n").forEach((line, index) => {
        const trimmed = line.trim();
        if (isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;
        if (/<Badge\b|from "@\/components\/ui\/badge"/.test(line)) return;

        for (const { re, label } of FORBIDDEN_PERMANENCE_PHRASES) {
          if (re.test(line)) {
            if (label === "streak" && isAllowedStreakContext(line)) continue;
            if (label === "ranking" && isAllowedRankingContext(line)) continue;
            violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
          }
        }
      });
    }


    for (const v of violations) fail(formatViolation(v));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkValidationOps() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const SCAN_DIRS = ["apps/web/app", "apps/web/components", "packages/shared/lib"];

    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      `${path.sep}api${path.sep}`,
      "apps/web/app/launch",
      "packages/shared/lib/research/",
      "packages/shared/lib/debug/validation-ops-review.ts",
      "scripts/",
    ];

    const FORBIDDEN_OPS_PHRASES = [
      { re: /\bgrowth hack\b/i, label: "growth hack" },
      { re: /\bengagement score\b/i, label: "engagement score" },
      { re: /\bconversion funnel\b/i, label: "conversion funnel" },
      { re: /\bdaily active\b/i, label: "daily active" },
      { re: /\bpower user\b/i, label: "power user" },
      { re: /\bgamif/i, label: "gamification" },
      { re: /\bstreak\b/i, label: "streak" },
      { re: /\blevel up\b/i, label: "level up" },
      { re: /\bproductivity\b/i, label: "productivity" },
      { re: /\bupgrade now\b/i, label: "upgrade now" },
      { re: /\bsubscribe now\b/i, label: "subscribe now" },
      { re: /\blimited time\b/i, label: "limited time" },
      { re: /\bdashboard\b/i, label: "dashboard" },
      { re: /\bachievement\b/i, label: "achievement" },
      { re: /\boptimize engagement\b/i, label: "optimize engagement" },
    ];

    const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

    function shouldSkip(filePath) {
      const rel = path.relative(ROOT, filePath);
      return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
    }

    function walk(dir, out = []) {
      if (!fs.existsSync(dir)) return out;
      for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (shouldSkip(full)) continue;
        const stat = fs.statSync(full);
        if (stat.isDirectory()) walk(full, out);
        else if (EXT.has(path.extname(name))) out.push(full);
      }
      return out;
    }

    function isCommentLine(trimmed) {
      return (
        trimmed.startsWith("//") ||
        trimmed.startsWith("*") ||
        trimmed.startsWith("/*") ||
        trimmed.endsWith("*/")
      );
    }

    function isValidationScriptLine(trimmed) {
      return (
        trimmed.includes("validate:validation-ops") ||
        trimmed.includes("validate-validation-ops-restraint")
      );
    }

    function isAllowedStreakContext(line) {
      return /\b(?:no|not a)\s+streak\b/i.test(line);
    }

    function isAllowedDashboardContext(line) {
      return /\b(?:not a|no)\s+(?:growth\s+)?dashboard\b/i.test(line);
    }

    const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
    const violations = [];

    for (const file of files) {
      const isUserFacing =
        (file.includes(`${path.sep}app${path.sep}`) &&
          file.endsWith("page.tsx") &&
          !file.includes(`${path.sep}debug${path.sep}`)) ||
        (file.includes(`${path.sep}components${path.sep}`) &&
          !file.includes(`${path.sep}debug${path.sep}`));

      if (!isUserFacing) continue;

      const content = fs.readFileSync(file, "utf8");
      content.split("\n").forEach((line, index) => {
        const trimmed = line.trim();
        if (isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;

        for (const { re, label } of FORBIDDEN_OPS_PHRASES) {
          if (re.test(line)) {
            if (label === "streak" && isAllowedStreakContext(line)) continue;
            if (label === "dashboard" && isAllowedDashboardContext(line)) continue;
            violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
          }
        }
      });
    }


    for (const v of violations) fail(formatViolation(v));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkPilot() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const SCAN_DIRS = ["apps/web/app", "apps/web/components", "packages/shared/lib"];

    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      `${path.sep}api${path.sep}`,
      "packages/shared/lib/pilot/",
      "packages/shared/lib/monetization/",
      "packages/shared/lib/subscription.ts",
      "apps/web/components/billing/",
      "apps/web/app/pricing/",
      "scripts/",
    ];

    const FORBIDDEN_PILOT_PHRASES = [
      { re: /\bfomo\b/i, label: "FOMO" },
      { re: /\bfear of missing\b/i, label: "fear of missing" },
      { re: /\bact now\b/i, label: "act now" },
      { re: /\bhurry\b/i, label: "hurry" },
      { re: /\bcountdown\b/i, label: "countdown" },
      { re: /\blimited spots\b/i, label: "limited spots" },
      { re: /\bexclusive access\b/i, label: "exclusive access" },
      { re: /\bwaitlist\b/i, label: "waitlist" },
      { re: /\bjoin the waitlist\b/i, label: "join the waitlist" },
      { re: /\bstartup\b/i, label: "startup" },
      { re: /\bscale fast\b/i, label: "scale fast" },
      { re: /\bgrowth hack\b/i, label: "growth hack" },
      { re: /\bcreator monetization\b/i, label: "creator monetization" },
      { re: /\bproductivity\b/i, label: "productivity" },
      { re: /\bstreak\b/i, label: "streak" },
      { re: /\blevel up\b/i, label: "level up" },
      { re: /\bunlock features\b/i, label: "unlock features" },
      { re: /\bpremium intelligence\b/i, label: "premium intelligence" },
      { re: /\bupgrade your growth\b/i, label: "upgrade your growth" },
      { re: /\bai insights\b/i, label: "AI insights" },
      { re: /\bdon't miss\b/i, label: "don't miss" },
      { re: /\bnever lose\b/i, label: "never lose" },
    ];

    const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

    function shouldSkip(filePath) {
      const rel = path.relative(ROOT, filePath);
      return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
    }

    function walk(dir, out = []) {
      if (!fs.existsSync(dir)) return out;
      for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (shouldSkip(full)) continue;
        const stat = fs.statSync(full);
        if (stat.isDirectory()) walk(full, out);
        else if (EXT.has(path.extname(name))) out.push(full);
      }
      return out;
    }

    function isCommentLine(trimmed) {
      return (
        trimmed.startsWith("//") ||
        trimmed.startsWith("*") ||
        trimmed.startsWith("/*") ||
        trimmed.endsWith("*/")
      );
    }

    function isValidationScriptLine(trimmed) {
      return trimmed.includes("validate:pilot") || trimmed.includes("validate-pilot-restraint");
    }

    function isAllowedStreakContext(line) {
      return /\b(?:no|not a)\s+streak\b/i.test(line);
    }

    function isAllowedForbiddenContext(line) {
      return /\bFORBIDDEN\b|\bReject\b|\bNEVER\b/i.test(line);
    }

    const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
    const violations = [];

    for (const file of files) {
      const isUserFacing =
        (file.includes(`${path.sep}app${path.sep}`) &&
          file.endsWith("page.tsx") &&
          !file.includes(`${path.sep}debug${path.sep}`)) ||
        (file.includes(`${path.sep}components${path.sep}`) &&
          !file.includes(`${path.sep}debug${path.sep}`) &&
          !file.includes(`${path.sep}billing${path.sep}`));

      if (!isUserFacing) continue;

      const content = fs.readFileSync(file, "utf8");
      content.split("\n").forEach((line, index) => {
        const trimmed = line.trim();
        if (isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;
        if (isAllowedForbiddenContext(line)) return;

        for (const { re, label } of FORBIDDEN_PILOT_PHRASES) {
          if (re.test(line)) {
            if (label === "streak" && isAllowedStreakContext(line)) continue;
            violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
          }
        }
      });
    }


    for (const v of violations) fail(formatViolation(v));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkIntegrity() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const REQUIRED_FILES = [
      "docs/VOICE_MEMORY_PRINCIPLES.md",
      "packages/shared/lib/integrity/emotional-integrity.ts",
      "packages/shared/lib/integrity/removal-review.ts",
      "packages/shared/lib/integrity/archive-simplicity-review.ts",
      "packages/shared/lib/integrity/durability-review.ts",
      "packages/shared/lib/refinement/callback-deduplication.ts",
      "packages/shared/lib/debug/emotional-integrity-review.ts",
      "apps/web/app/internal/emotional-integrity/page.tsx",
      "apps/web/app/internal/archive-simplicity/page.tsx",
      "apps/web/app/internal/durability-review/page.tsx",
    ];

    const SCAN_DIRS = ["apps/web/app", "apps/web/components", "packages/shared/lib"];

    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      `${path.sep}api${path.sep}`,
      "packages/shared/lib/integrity/",
      "packages/shared/lib/refinement/callback-deduplication.ts",
      "packages/shared/lib/debug/emotional-integrity-review.ts",
      "packages/shared/lib/debug/emotional-legitimacy-review.ts",
      "packages/shared/lib/research/founder-warnings.ts",
      "docs/",
      "scripts/",
    ];

    const FORBIDDEN_INTEGRITY_PHRASES = [
      { re: /\bgrowth hack\b/i, label: "growth hack" },
      { re: /\bproductivity\b/i, label: "productivity" },
      { re: /\bstreak\b/i, label: "streak" },
      { re: /\blevel up\b/i, label: "level up" },
      { re: /\bhealing journey\b/i, label: "healing journey" },
      { re: /\bbest self\b/i, label: "best self" },
      { re: /\bdon't miss\b/i, label: "don't miss" },
      { re: /\bact now\b/i, label: "act now" },
      { re: /\bunlock features\b/i, label: "unlock features" },
      { re: /\bpremium intelligence\b/i, label: "premium intelligence" },
      { re: /\bai insights\b/i, label: "AI insights" },
      { re: /\boptimize engagement\b/i, label: "optimize engagement" },
      { re: /\bconversion funnel\b/i, label: "conversion funnel" },
      { re: /\bwaitlist\b/i, label: "waitlist" },
      { re: /\bexclusive access\b/i, label: "exclusive access" },
    ];

    const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

    const missing = partitionRetiredWebRequirements(REQUIRED_FILES, fail).filter(
      (rel) => !fs.existsSync(path.join(ROOT, rel)),
    );
    if (missing.length > 0) {
        for (const file of missing) fail(`missing file: ${file}`);
      }

    const principles = fs.readFileSync(path.join(ROOT, "docs/VOICE_MEMORY_PRINCIPLES.md"), "utf8");
    const requiredPrincipleLines = [
      "silence over filler",
      "continuity over novelty",
      "archive permanence over engagement",
      "no productivity framing",
      "no emotional manipulation",
    ];
    for (const line of requiredPrincipleLines) {
      if (!principles.toLowerCase().includes(line)) fail(`principles doc missing: "${line}"`);
    }

    const emotionalIntegrity = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/integrity/emotional-integrity.ts"),
      "utf8",
    );
    if (!emotionalIntegrity.includes("The product may be explaining too much.")) fail("missing explaining-too-much founder warning");

    function shouldSkip(filePath) {
      const rel = path.relative(ROOT, filePath);
      return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
    }

    function walk(dir, out = []) {
      if (!fs.existsSync(dir)) return out;
      for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (shouldSkip(full)) continue;
        const stat = fs.statSync(full);
        if (stat.isDirectory()) walk(full, out);
        else if (EXT.has(path.extname(name))) out.push(full);
      }
      return out;
    }

    function isCommentLine(trimmed) {
      return (
        trimmed.startsWith("//") ||
        trimmed.startsWith("*") ||
        trimmed.startsWith("/*") ||
        trimmed.endsWith("*/")
      );
    }

    function isAllowedStreakContext(line) {
      return /\b(?:no|not a)\s+streak\b/i.test(line);
    }

    const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
    const violations = [];

    for (const file of files) {
      const isUserFacing =
        (file.includes(`${path.sep}app${path.sep}`) &&
          file.endsWith("page.tsx") &&
          !file.includes(`${path.sep}debug${path.sep}`)) ||
        (file.includes(`${path.sep}components${path.sep}`) &&
          !file.includes(`${path.sep}debug${path.sep}`));

      if (!isUserFacing) continue;

      const content = fs.readFileSync(file, "utf8");
      content.split("\n").forEach((line, index) => {
        const trimmed = line.trim();
        if (isCommentLine(trimmed)) return;

        for (const { re, label } of FORBIDDEN_INTEGRITY_PHRASES) {
          if (re.test(line)) {
            if (label === "streak" && isAllowedStreakContext(line)) continue;
            violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
          }
        }
      });
    }


    for (const v of violations) fail(formatViolation(v));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkIndividuality() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const REQUIRED_FILES = [
      "packages/shared/lib/identity/archive-individuality.ts",
      "packages/shared/lib/identity/personalized-restraint.ts",
      "packages/shared/lib/identity/voice-texture.ts",
      "packages/shared/lib/identity/longitudinal-individuality.ts",
      "packages/shared/lib/refinement/anti-template.ts",
      "packages/shared/lib/debug/archive-individuality-review.ts",
      "packages/shared/lib/debug/archive-divergence-review.ts",
      "apps/web/app/internal/archive-individuality/page.tsx",
      "apps/web/app/internal/archive-divergence/page.tsx",
    ];

    const SCAN_DIRS = ["apps/web/app", "apps/web/components", "packages/shared/lib"];

    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      `${path.sep}api${path.sep}`,
      "packages/shared/lib/identity/",
      "packages/shared/lib/refinement/anti-template.ts",
      "packages/shared/lib/debug/archive-individuality-review.ts",
      "packages/shared/lib/debug/archive-divergence-review.ts",
      "packages/shared/lib/research/founder-warnings.ts",
      "packages/shared/lib/memory/language-fingerprint.ts",
      "scripts/",
    ];

    const FORBIDDEN_INDIVIDUALITY_PHRASES = [
      { re: /\bpsychographic\b/i, label: "psychographic" },
      { re: /\bpersonality type\b/i, label: "personality type" },
      { re: /\bmbti\b/i, label: "MBTI" },
      { re: /\benneagram\b/i, label: "enneagram" },
      { re: /\bintrovert\b/i, label: "introvert typing" },
      { re: /\bextrovert\b/i, label: "extrovert typing" },
      { re: /\boptimize your\b/i, label: "optimize your" },
      { re: /\bpersonalized for you\b/i, label: "personalized for you" },
      { re: /\btailored experience\b/i, label: "tailored experience" },
      { re: /\buser segment\b/i, label: "user segment" },
      { re: /\bcohort profile\b/i, label: "cohort profile" },
      { re: /\bproductivity\b/i, label: "productivity" },
      { re: /\bgrowth hack\b/i, label: "growth hack" },
      { re: /\bmanipulative personalization\b/i, label: "manipulative personalization" },
      { re: /\byour archetype\b/i, label: "your archetype" },
      { re: /\bemotional type\b/i, label: "emotional type" },
    ];

    const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

    const missing = partitionRetiredWebRequirements(REQUIRED_FILES, fail).filter(
      (rel) => !fs.existsSync(path.join(ROOT, rel)),
    );
    if (missing.length > 0) {
        for (const file of missing) fail(`missing file: ${file}`);
      }

    const antiTemplate = fs.readFileSync(path.join(ROOT, "packages/shared/lib/refinement/anti-template.ts"), "utf8");
    if (!antiTemplate.includes("This callback may sound generated.")) fail("missing anti-template warning");

    const individualityReview = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/debug/archive-individuality-review.ts"),
      "utf8",
    );
    if (!individualityReview.includes("The product may be losing emotional specificity.")) fail("missing specificity founder warning");

    function shouldSkip(filePath) {
      const rel = path.relative(ROOT, filePath);
      return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
    }

    function walk(dir, out = []) {
      if (!fs.existsSync(dir)) return out;
      for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (shouldSkip(full)) continue;
        const stat = fs.statSync(full);
        if (stat.isDirectory()) walk(full, out);
        else if (EXT.has(path.extname(name))) out.push(full);
      }
      return out;
    }

    function isCommentLine(trimmed) {
      return (
        trimmed.startsWith("//") ||
        trimmed.startsWith("*") ||
        trimmed.startsWith("/*") ||
        trimmed.endsWith("*/")
      );
    }

    const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
    const violations = [];

    for (const file of files) {
      const isUserFacing =
        (file.includes(`${path.sep}app${path.sep}`) &&
          file.endsWith("page.tsx") &&
          !file.includes(`${path.sep}debug${path.sep}`)) ||
        (file.includes(`${path.sep}components${path.sep}`) &&
          !file.includes(`${path.sep}debug${path.sep}`));

      if (!isUserFacing) continue;

      const content = fs.readFileSync(file, "utf8");
      content.split("\n").forEach((line, index) => {
        const trimmed = line.trim();
        if (isCommentLine(trimmed)) return;

        for (const { re, label } of FORBIDDEN_INDIVIDUALITY_PHRASES) {
          if (re.test(line)) {
            violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
          }
        }
      });
    }


    for (const v of violations) fail(formatViolation(v));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkSacredness() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const REQUIRED_FILES = [
      "packages/shared/lib/restraint/sacredness.ts",
      "packages/shared/lib/restraint/earned-resurfacing.ts",
      "packages/shared/lib/restraint/silence-first.ts",
      "packages/shared/lib/restraint/non-intervention.ts",
      "packages/shared/lib/restraint/restraint-escalation.ts",
      "packages/shared/lib/refinement/rarity-preservation.ts",
      "packages/shared/lib/debug/sacredness-review.ts",
      "apps/web/app/internal/sacredness-review/page.tsx",
    ];

    const SCAN_DIRS = ["apps/web/app", "apps/web/components", "packages/shared/lib"];

    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      `${path.sep}api${path.sep}`,
      "packages/shared/lib/restraint/",
      "packages/shared/lib/refinement/rarity-preservation.ts",
      "packages/shared/lib/debug/sacredness-review.ts",
      "packages/shared/lib/research/founder-warnings.ts",
      "packages/shared/lib/refinement/anti-template.ts",
      "scripts/",
    ];

    const FORBIDDEN_SACREDNESS_PHRASES = [
      { re: /\bemotional oversupply\b/i, label: "emotional oversupply" },
      { re: /\bfake profundity\b/i, label: "fake profundity" },
      { re: /\bprofound insight\b/i, label: "profound insight" },
      { re: /\blife-changing\b/i, label: "life-changing" },
      { re: /\boptimize engagement\b/i, label: "optimize engagement" },
      { re: /\bdon't miss this\b/i, label: "don't miss this" },
      { re: /\bact now\b/i, label: "act now" },
      { re: /\bstreak\b/i, label: "streak" },
      { re: /\bproductivity\b/i, label: "productivity" },
      { re: /\bgrowth hack\b/i, label: "growth hack" },
      { re: /\bunlock insights\b/i, label: "unlock insights" },
      { re: /\bdaily habit\b/i, label: "daily habit" },
      { re: /\bmeaningful moment streak\b/i, label: "meaningful moment streak" },
      { re: /\byour breakthrough\b/i, label: "your breakthrough" },
      { re: /\bhealing journey\b/i, label: "healing journey" },
    ];

    const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

    const missing = partitionRetiredWebRequirements(REQUIRED_FILES, fail).filter(
      (rel) => !fs.existsSync(path.join(ROOT, rel)),
    );
    if (missing.length > 0) {
        for (const file of missing) fail(`missing file: ${file}`);
      }

    const sacredness = fs.readFileSync(path.join(ROOT, "packages/shared/lib/restraint/sacredness.ts"), "utf8");
    const requiredWarnings = [
      "The archive may be becoming emotionally crowded.",
      "Too many moments are being treated as meaningful.",
      "Silence may now be more valuable than resurfacing.",
    ];
    for (const line of requiredWarnings) {
      if (!sacredness.includes(line)) fail(`missing founder warning: "${line}"`);
    }

    const nonIntervention = fs.readFileSync(path.join(ROOT, "packages/shared/lib/restraint/non-intervention.ts"), "utf8");
    if (!nonIntervention.includes("Nothing should surface right now")) fail("missing non-intervention conclusion");

    function shouldSkip(filePath) {
      const rel = path.relative(ROOT, filePath);
      return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
    }

    function walk(dir, out = []) {
      if (!fs.existsSync(dir)) return out;
      for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (shouldSkip(full)) continue;
        const stat = fs.statSync(full);
        if (stat.isDirectory()) walk(full, out);
        else if (EXT.has(path.extname(name))) out.push(full);
      }
      return out;
    }

    function isCommentLine(trimmed) {
      return (
        trimmed.startsWith("//") ||
        trimmed.startsWith("*") ||
        trimmed.startsWith("/*") ||
        trimmed.endsWith("*/")
      );
    }

    function isAllowedStreakContext(line) {
      return /\b(?:no|not a)\s+streak\b/i.test(line);
    }

    const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
    const violations = [];

    for (const file of files) {
      const isUserFacing =
        (file.includes(`${path.sep}app${path.sep}`) &&
          file.endsWith("page.tsx") &&
          !file.includes(`${path.sep}debug${path.sep}`)) ||
        (file.includes(`${path.sep}components${path.sep}`) &&
          !file.includes(`${path.sep}debug${path.sep}`));

      if (!isUserFacing) continue;

      const content = fs.readFileSync(file, "utf8");
      content.split("\n").forEach((line, index) => {
        const trimmed = line.trim();
        if (isCommentLine(trimmed)) return;

        for (const { re, label } of FORBIDDEN_SACREDNESS_PHRASES) {
          if (re.test(line)) {
            if (label === "streak" && isAllowedStreakContext(line)) continue;
            violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
          }
        }
      });
    }


    for (const v of violations) fail(formatViolation(v));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkPersonalization() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const REQUIRED_FILES = [
      "packages/shared/lib/personalization/visual-tone.ts",
      "packages/shared/lib/personalization/ambient-adaptation.ts",
      "packages/shared/lib/personalization/photo-preferences.ts",
      "packages/shared/lib/personalization/soft-emotional-timeline.ts",
      "packages/shared/lib/photo-storage.ts",
      "packages/shared/lib/photo/compress.ts",
      "packages/shared/lib/photo/integrity.ts",
      "apps/web/components/settings/PersonalizationSettings.tsx",
      "apps/web/components/entry/EntryPhotoAttachment.tsx",
      "apps/web/app/feelings-timeline/page.tsx",
    ];

    const SCAN_DIRS = ["apps/web/app", "apps/web/components", "packages/shared/lib"];

    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      `${path.sep}api${path.sep}`,
      "packages/shared/lib/personalization/",
      "packages/shared/lib/photo-storage.ts",
      "packages/shared/lib/photo/",
      "packages/shared/lib/atmosphere/",
      "apps/web/components/settings/PersonalizationSettings.tsx",
      "apps/web/components/entry/EntryPhotoAttachment.tsx",
      "apps/web/components/entry/EntryAtmosphereAttachment.tsx",
      "apps/web/app/feelings-timeline/",
      "scripts/",
    ];

    const FORBIDDEN_PERSONALIZATION_PHRASES = [
      { re: /\bmood dashboard\b/i, label: "mood dashboard" },
      { re: /\bproductivity chart\b/i, label: "productivity chart" },
      { re: /\bemotion tracking\b/i, label: "emotion tracking" },
      { re: /\bgamified emotion\b/i, label: "gamified emotion" },
      { re: /\bsticker\b/i, label: "sticker" },
      { re: /\bcute diary\b/i, label: "cute diary" },
      { re: /\bchildish customization\b/i, label: "childish customization" },
      { re: /\bai[- ]generated memory art\b/i, label: "AI-generated memory art" },
      { re: /\bgenerate.*image\b/i, label: "generate image" },
      { re: /\bphoto feed\b/i, label: "photo feed" },
      { re: /\binstagram\b/i, label: "instagram" },
      { re: /\bphoto filters?\b/i, label: "photo filters" },
      { re: /\bimage filters?\b/i, label: "image filters" },
      { re: /\bemoji theme\b/i, label: "emoji theme" },
      { re: /\bbright theme\b/i, label: "bright theme" },
      { re: /\bhabit tracker\b/i, label: "habit tracker" },
    ];

    const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

    const missing = partitionRetiredWebRequirements(REQUIRED_FILES, fail).filter(
      (rel) => !fs.existsSync(path.join(ROOT, rel)),
    );
    if (missing.length > 0) {
        for (const file of missing) fail(`missing file: ${file}`);
      }

    if (!deferRetiredWebSurface("apps/web/app/feelings-timeline/page.tsx", fail)) {
      const feelingsPage = fs.readFileSync(
        path.join(ROOT, "apps/web/app/feelings-timeline/page.tsx"),
        "utf8",
      );
      if (!feelingsPage.includes("How this has felt over time")) fail("missing soft timeline copy");
    }

    function shouldSkip(filePath) {
      const rel = path.relative(ROOT, filePath);
      return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
    }

    function walk(dir, out = []) {
      if (!fs.existsSync(dir)) return out;
      for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (shouldSkip(full)) continue;
        const stat = fs.statSync(full);
        if (stat.isDirectory()) walk(full, out);
        else if (EXT.has(path.extname(name))) out.push(full);
      }
      return out;
    }

    function isCommentLine(trimmed) {
      return (
        trimmed.startsWith("//") ||
        trimmed.startsWith("*") ||
        trimmed.startsWith("/*") ||
        trimmed.endsWith("*/")
      );
    }

    function isAllowedFilterContext(line) {
      return /\bno filters\b/i.test(line) || /FORBIDDEN.*filter/i.test(line);
    }

    const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
    const violations = [];

    for (const file of files) {
      const isUserFacing =
        (file.includes(`${path.sep}app${path.sep}`) &&
          file.endsWith("page.tsx") &&
          !file.includes(`${path.sep}debug${path.sep}`)) ||
        (file.includes(`${path.sep}components${path.sep}`) &&
          !file.includes(`${path.sep}debug${path.sep}`));

      if (!isUserFacing) continue;

      const content = fs.readFileSync(file, "utf8");
      content.split("\n").forEach((line, index) => {
        const trimmed = line.trim();
        if (isCommentLine(trimmed)) return;

        for (const { re, label } of FORBIDDEN_PERSONALIZATION_PHRASES) {
          if (re.test(line)) {
            if (label === "photo filters" && isAllowedFilterContext(line)) continue;
            violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
          }
        }
      });
    }


    for (const v of violations) fail(formatViolation(v));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkTerritories() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const REQUIRED_FILES = [
      "packages/shared/lib/territories/emotional-territories.ts",
      "packages/shared/lib/territories/territory-preferences.ts",
      "packages/shared/lib/territories/territory-observation.ts",
      "packages/shared/types/emotional-territory.ts",
      "apps/web/components/territories/TerritorySections.tsx",
      "apps/web/components/territories/TerritoryRenameControl.tsx",
      "apps/web/app/territories/page.tsx",
      "apps/web/app/territories/[slug]/page.tsx",
    ];

    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      `${path.sep}api${path.sep}`,
      "packages/shared/lib/territories/",
      "apps/web/components/territories/",
      "apps/web/app/territories/",
      "scripts/",
    ];

    const FORBIDDEN_PHRASES = [
      { re: /\bmood dashboard\b/i, label: "mood dashboard" },
      { re: /\bmood taxonomy\b/i, label: "mood taxonomy" },
      { re: /\bclinical categor/i, label: "clinical categories" },
      { re: /\bproductivity dashboard\b/i, label: "productivity dashboard" },
      { re: /\bproductivity chart\b/i, label: "productivity chart" },
      { re: /\bemotion tracking\b/i, label: "emotion tracking" },
      { re: /\bhabit tracker\b/i, label: "habit tracker" },
      { re: /\bscoreboard\b/i, label: "scoreboard" },
    ];

    const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);
    const SCAN_DIRS = ["apps/web/app", "apps/web/components", "packages/shared/lib"];

    const missing = partitionRetiredWebRequirements(REQUIRED_FILES, fail).filter(
      (rel) => !fs.existsSync(path.join(ROOT, rel)),
    );
    if (missing.length > 0) {
        for (const file of missing) fail(`missing file: ${file}`);
      }

    if (!deferRetiredWebSurface("apps/web/app/territories/page.tsx", fail)) {
      const territoriesPage = fs.readFileSync(path.join(ROOT, "apps/web/app/territories/page.tsx"), "utf8");
      if (!territoriesPage.includes("Emotional territories")) fail("missing page title");
    }

    const coreLib = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/territories/emotional-territories.ts"),
      "utf8",
    );
    for (const label of ["Around work", "Around home", "About money"]) {
      if (!coreLib.includes(label)) fail(`missing copy example "${label}"`);
    }

    function shouldSkip(filePath) {
      const rel = path.relative(ROOT, filePath);
      return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
    }

    function walk(dir, out = []) {
      if (!fs.existsSync(dir)) return out;
      for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (shouldSkip(full)) continue;
        const stat = fs.statSync(full);
        if (stat.isDirectory()) walk(full, out);
        else if (EXT.has(path.extname(name))) out.push(full);
      }
      return out;
    }

    function isCommentLine(trimmed) {
      return (
        trimmed.startsWith("//") ||
        trimmed.startsWith("*") ||
        trimmed.startsWith("/*") ||
        trimmed.endsWith("*/")
      );
    }

    function isAllowedContext(line, label) {
      if (label === "diagnosis") {
        return /\bnot (?:therapy or )?diagnosis\b/i.test(line) || /\bno diagnosis\b/i.test(line);
      }
      return false;
    }

    const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
    const violations = [];

    for (const file of files) {
      const isUserFacing =
        (file.includes(`${path.sep}app${path.sep}`) &&
          file.endsWith("page.tsx") &&
          !file.includes(`${path.sep}debug${path.sep}`)) ||
        (file.includes(`${path.sep}components${path.sep}`) &&
          !file.includes(`${path.sep}debug${path.sep}`));

      if (!isUserFacing) continue;

      const content = fs.readFileSync(file, "utf8");
      content.split("\n").forEach((line, index) => {
        const trimmed = line.trim();
        if (isCommentLine(trimmed)) return;

        for (const { re, label } of FORBIDDEN_PHRASES) {
          if (re.test(line)) {
            if (isAllowedContext(line, label)) continue;
            violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
          }
        }
      });
    }


    for (const v of violations) fail(formatViolation(v));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkAtmosphere() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const REQUIRED_FILES = [
      "packages/shared/lib/atmosphere/memory-atmosphere.ts",
      "packages/shared/lib/atmosphere/atmosphere-anchors.ts",
      "packages/shared/lib/atmosphere/atmosphere-storage.ts",
      "packages/shared/lib/atmosphere/atmosphere-observation.ts",
      "packages/shared/types/atmosphere.ts",
      "apps/web/components/entry/EntryAtmosphereAttachment.tsx",
      "apps/api/app/api/atmosphere/route.ts",
    ];

    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      "packages/shared/lib/atmosphere/",
      "apps/web/components/entry/EntryAtmosphereAttachment.tsx",
      "apps/api/app/api/atmosphere/",
      "scripts/",
    ];

    const FORBIDDEN_PHRASES = [
      { re: /\bai interpreted your soul\b/i, label: "AI interpreted your soul" },
      { re: /\bfantasy art\b/i, label: "fantasy art" },
      { re: /\bcinematic trauma\b/i, label: "cinematic trauma" },
      { re: /\btherapy symbolism\b/i, label: "therapy symbolism" },
      { re: /\bautomatic generation\b/i, label: "automatic generation" },
      { re: /\banimated background\b/i, label: "animated background" },
      { re: /\bgenerate.*image\b/i, label: "generate image" },
      { re: /\bai[- ]generated memory art\b/i, label: "AI-generated memory art" },
      { re: /\bphoto feed\b/i, label: "photo feed" },
      { re: /\bbright theme\b/i, label: "bright theme" },
    ];

    const WALLPAPER_LABELS = [
      "Foggy street",
      "Morning glow",
      "Quiet room",
      "Soft light",
      "Rainy window",
      "Dusk field",
      "Abstract color field",
      "Create quiet atmosphere",
      "A quiet visual, not a memory",
    ];

    const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);
    const SCAN_DIRS = ["apps/web/app", "apps/web/components", "packages/shared/lib"];

    const missing = partitionRetiredWebRequirements(REQUIRED_FILES, fail).filter(
      (rel) => !fs.existsSync(path.join(ROOT, rel)),
    );
    if (missing.length > 0) {
        for (const file of missing) fail(`missing file: ${file}`);
      }

    const typesAtmosphere = fs.readFileSync(path.join(ROOT, "packages/shared/types/atmosphere.ts"), "utf8");
    if (!typesAtmosphere.includes("AtmosphereFingerprint")) fail("types/atmosphere.ts must define AtmosphereFingerprint");

    const memoryAtmosphere = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/atmosphere/memory-atmosphere.ts"),
      "utf8",
    );
    if (!memoryAtmosphere.includes("fingerprint")) fail("buildAtmosphereMeta must attach fingerprint");

    const anchors = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/atmosphere/atmosphere-anchors.ts"),
      "utf8",
    );
    for (const token of ["EMOTIONAL_ATMOSPHERE_CATALOG", "buildAtmosphereFingerprint", "pickEmotionalContextLine"]) {
      if (!anchors.includes(token)) fail(`atmosphere-anchors.ts must export ${token}`);
    }

    const atmosphereComponentDeferred = deferRetiredWebSurface(
      "apps/web/components/entry/EntryAtmosphereAttachment.tsx",
      fail,
    );
    const component = atmosphereComponentDeferred
      ? ""
      : fs.readFileSync(
          path.join(ROOT, "apps/web/components/entry/EntryAtmosphereAttachment.tsx"),
          "utf8",
        );
    const componentMarkers = [
      ["A visual echo", "ATMOSPHERE_SECTION_TITLE"],
      ["Add a visual echo", "ATMOSPHERE_EXPAND_LABEL"],
      ["Generate another", "ATMOSPHERE_GENERATE_ANOTHER"],
      ["Generated images may not match what happened.", "ATMOSPHERE_SECTION_DISCLAIMER"],
      "buildAtmospherePickerPresentation",
      "AtmosphereChoiceCard",
    ];
    if (!atmosphereComponentDeferred) {
      for (const marker of componentMarkers) {
        const options = Array.isArray(marker) ? marker : [marker];
        if (!options.some((token) => component.includes(token))) fail(`missing ${options.join(" or ")} in EntryAtmosphereAttachment`);
      }

      for (const banned of WALLPAPER_LABELS) {
        if (component.includes(banned)) fail(`wallpaper-picker label "${banned}" in EntryAtmosphereAttachment`);
      }

      if (component.includes("ATMOSPHERE_STYLE_OPTIONS")) fail("equal-weight style grid must not appear in EntryAtmosphereAttachment");
    }

    if (!anchors.includes("A visual echo")) fail('atmosphere-anchors must define "A visual echo" title');

    function shouldSkip(filePath) {
      const rel = path.relative(ROOT, filePath);
      return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
    }

    function walk(dir, out = []) {
      if (!fs.existsSync(dir)) return out;
      for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (shouldSkip(full)) continue;
        const stat = fs.statSync(full);
        if (stat.isDirectory()) walk(full, out);
        else if (EXT.has(path.extname(name))) out.push(full);
      }
      return out;
    }

    function isCommentLine(trimmed) {
      return (
        trimmed.startsWith("//") ||
        trimmed.startsWith("*") ||
        trimmed.startsWith("/*") ||
        trimmed.endsWith("*/")
      );
    }

    function isAllowedContext(line, label) {
      if (label === "fantasy art" || label === "automatic generation" || label === "generate image") {
        return /\bno fantasy\b/i.test(line) || /\bnever automatic\b/i.test(line) || /\bnot a memory\b/i.test(line);
      }
      return false;
    }

    const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
    const violations = [];

    for (const file of files) {
      const isUserFacing =
        (file.includes(`${path.sep}app${path.sep}`) &&
          file.endsWith("page.tsx") &&
          !file.includes(`${path.sep}debug${path.sep}`)) ||
        (file.includes(`${path.sep}components${path.sep}`) &&
          !file.includes(`${path.sep}debug${path.sep}`));

      if (!isUserFacing) continue;

      const content = fs.readFileSync(file, "utf8");
      content.split("\n").forEach((line, index) => {
        const trimmed = line.trim();
        if (isCommentLine(trimmed)) return;

        for (const { re, label } of FORBIDDEN_PHRASES) {
          if (re.test(line)) {
            if (isAllowedContext(line, label)) continue;
            violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
          }
        }
      });
    }


    for (const v of violations) fail(formatViolation(v));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkCompounding() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const SCAN_DIRS = ["apps/web/app", "apps/web/components", "packages/shared/lib"];

    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      `${path.sep}api${path.sep}`,
      "packages/shared/lib/memory/memory-compounding.ts",
      "packages/shared/lib/memory/slow-realizations.ts",
      "apps/web/components/ui/badge.tsx",
      "scripts/",
    ];

    const FORBIDDEN_COMPOUNDING_PHRASES = [
      { re: /\btransformed\b/i, label: "transformed" },
      { re: /\bhealing journey\b/i, label: "healing journey" },
      { re: /\bself-improvement\b/i, label: "self-improvement" },
      { re: /\bgrowth journey\b/i, label: "growth journey" },
      { re: /\bbest self\b/i, label: "best self" },
      { re: /\bbreakthrough\b/i, label: "breakthrough" },
      { re: /\bachievement\b/i, label: "achievement" },
      { re: /\bbadge earned\b/i, label: "badge earned" },
      { re: /\bearned badge\b/i, label: "earned badge" },
      { re: /\bstreak\b/i, label: "streak" },
      { re: /\blevel up\b/i, label: "level up" },
      { re: /\bprogress score\b/i, label: "progress score" },
      { re: /\barchive depth score\b/i, label: "archive depth score" },
      { re: /\bdaily habit\b/i, label: "daily habit" },
    ];

    const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

    function shouldSkip(filePath) {
      const rel = path.relative(ROOT, filePath);
      return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
    }

    function walk(dir, out = []) {
      if (!fs.existsSync(dir)) return out;
      for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (shouldSkip(full)) continue;
        const stat = fs.statSync(full);
        if (stat.isDirectory()) walk(full, out);
        else if (EXT.has(path.extname(name))) out.push(full);
      }
      return out;
    }

    function isCommentLine(trimmed) {
      return (
        trimmed.startsWith("//") ||
        trimmed.startsWith("*") ||
        trimmed.startsWith("/*") ||
        trimmed.endsWith("*/")
      );
    }

    function isValidationScriptLine(trimmed) {
      return (
        trimmed.includes("validate:compounding") ||
        trimmed.includes("validate-compounding-restraint")
      );
    }

    function isAllowedStreakContext(line) {
      return /\b(?:no|not a)\s+streak\b/i.test(line);
    }

    const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
    const violations = [];

    for (const file of files) {
      const isUserFacing =
        (file.includes(`${path.sep}app${path.sep}`) &&
          file.endsWith("page.tsx") &&
          !file.includes(`${path.sep}debug${path.sep}`)) ||
        (file.includes(`${path.sep}components${path.sep}`) &&
          !file.includes(`${path.sep}debug${path.sep}`));

      if (!isUserFacing) continue;

      const content = fs.readFileSync(file, "utf8");
      content.split("\n").forEach((line, index) => {
        const trimmed = line.trim();
        if (isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;
        if (/<Badge\b|from "@\/components\/ui\/badge"/.test(line)) return;

        for (const { re, label } of FORBIDDEN_COMPOUNDING_PHRASES) {
          if (re.test(line)) {
            if (label === "streak" && isAllowedStreakContext(line)) continue;
            violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
          }
        }
      });
    }


    for (const v of violations) fail(formatViolation(v));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkInstallPromptRestraint() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const failures = [];

    const gate = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/mobile/install-prompt-gate.ts"),
      "utf8",
    );
    for (const token of [
      "hasInstallPromptEligibility",
      "shouldShowInstallPrompt",
      "countCompletedReflections",
      "isRecorderSurfaceActive",
      "isMicPermissionRequestActive",
      "/record",
      "/entry/",
    ]) {
      if (!gate.includes(token)) failures.push(`install-prompt-gate missing ${token}`);
    }

    // The gate module above is live shared code and stays enforced. The web
    // install prompt itself is retired: production web is a marketing site and
    // the consumer product is the native app in apps/mobile, so there is no
    // PWA install surface to restrain.
    if (!deferRetiredWebSurface("apps/web/components/mobile/InstallPrompt.tsx", (m) => failures.push(m))) {
      const install = fs.readFileSync(
        path.join(ROOT, "apps/web/components/mobile/InstallPrompt.tsx"),
        "utf8",
      );
      if (!install.includes("shouldShowInstallPrompt") || !install.includes("usePathname")) {
        failures.push("InstallPrompt must gate on route and eligibility");
      }
    }


    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkPwaRestraint() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const INSTALL_FILE = path.join(ROOT, "apps/web/components/mobile/InstallPrompt.tsx");
    const SCAN = [
      path.join(ROOT, "apps/web/components/mobile/InstallPrompt.tsx"),
      path.join(ROOT, "apps/web/components/mobile/PwaBootstrap.tsx"),
      path.join(ROOT, "apps/web/app/pricing/page.tsx"),
    ];

    const BANNED = [
      /\binstall now\b/i,
      /\bact now\b/i,
      /\bhurry\b/i,
      /\blimited time\b/i,
      /\byou must install\b/i,
      /\bdon't miss\b/i,
    ];

    const failures = [];
    const pushFail = (m) => failures.push(m);

    if (!fs.existsSync(path.join(ROOT, "packages/shared/lib/mobile/install-prompt-gate.ts"))) {
      failures.push("install-prompt-gate module required");
    }

    // Same retirement as above: the install prompt and PWA bootstrap were
    // consumer-web surfaces. The manifest is still live and still checked.
    if (!deferRetiredWebSurface("apps/web/components/mobile/InstallPrompt.tsx", pushFail)) {
      const install = fs.readFileSync(INSTALL_FILE, "utf8");
      if (!install.includes("beforeinstallprompt")) {
        failures.push("InstallPrompt must listen for beforeinstallprompt");
      }
      if (!install.match(/dismiss|Not now/i)) {
        failures.push("InstallPrompt must allow dismiss");
      }
    }

    for (const file of SCAN) {
      if (!fs.existsSync(file)) {
        const rel = path.relative(ROOT, file);
        if (rel.startsWith("apps/web/")) {
          deferRetiredWebSurface(rel, pushFail);
          continue;
        }
        failures.push(`${rel}: missing`);
        continue;
      }
      const content = fs.readFileSync(file, "utf8");
      for (const re of BANNED) {
        if (re.test(content)) {
          failures.push(`${path.relative(ROOT, file)}: banned phrase ${re}`);
        }
      }
    }

    const manifest = fs.readFileSync(path.join(ROOT, "apps/web/app/manifest.ts"), "utf8");
    if (!manifest.includes('display: "standalone"')) {
      failures.push("manifest must use standalone display");
    }


    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkVulnerabilityTiming() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const failures = [];
    const REQUIRED = [
      "packages/shared/lib/capture/vulnerability-timing.ts",
      "packages/shared/types/vulnerability-timing.ts",
      "apps/web/app/internal/vulnerability-timing/page.tsx",
      "apps/web/components/internal/VulnerabilityTimingPanel.tsx",
    ];

    for (const rel of partitionRetiredWebRequirements(REQUIRED, (m) => failures.push(m))) {
      if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
    }

    const vuln = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/capture/vulnerability-timing.ts"),
      "utf8",
    );
    for (const token of [
      "time_to_mic_ms",
      "time_to_recording_started_ms",
      "time_to_vulnerable_phrase_ms",
      "vulnerable_phrase_detected",
      "buildVulnerabilityTimingReport",
    ]) {
      if (!vuln.includes(token)) failures.push(`vulnerability-timing missing ${token}`);
    }

    const productPages = ["apps/web/app/page.tsx", "apps/web/app/record/page.tsx", "apps/web/components/Recorder.tsx"];
    for (const rel of productPages) {
      if (!fs.existsSync(path.join(ROOT, rel))) {
        deferRetiredWebSurface(rel, (m) => failures.push(m));
        continue;
      }
      const text = fs.readFileSync(path.join(ROOT, rel), "utf8");
      if (text.includes("buildVulnerabilityTimingReport")) {
        failures.push(`${rel} must not expose vulnerability report in product UI`);
      }
    }

    const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
    if (!pkg.includes("validate:restraint")) {
      failures.push("package.json must wire validate:restraint");
    }


    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkProductSimplification() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const required = [
      "packages/shared/lib/product/archive-product-model.ts",
      "packages/shared/types/archive-product-model.ts",
      "packages/shared/lib/product/archive-product-questions.ts",
      "packages/shared/lib/product/surface-audit.ts",
      "packages/shared/lib/internal/product-simplification-report.ts",
      "apps/web/components/archive/ArchiveCommandCenter.tsx",
      "apps/web/components/archive/ArchiveDetailsCollapsible.tsx",
      "packages/shared/lib/product/product-simplification-copy.ts",
      "scripts/validate-surface-complexity.mjs",
    ];

    spawnSync("node", ["scripts/validate-surface-complexity.mjs"], {
      cwd: ROOT,
      stdio: "inherit",
    });
    if (!fs.existsSync(path.join(ROOT, "docs/SURFACE_COMPLEXITY_REPORT.md"))) {
      fail("docs/SURFACE_COMPLEXITY_REPORT.md not generated");
    }

    for (const rel of partitionRetiredWebRequirements(required, fail)) {
      if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
    }

    if (!deferRetiredWebSurface("apps/web/components/archive/EvidenceArchiveHome.tsx", fail)) {
      const home = fs.readFileSync(
        path.join(ROOT, "apps/web/components/archive/EvidenceArchiveHome.tsx"),
        "utf8",
      );
      for (const token of [
        "ArchiveCommandCenter",
        "ArchiveDetailsCollapsible",
        "PAGE_TITLE_ARCHIVE",
      ]) {
        if (!home.includes(token)) fail(`EvidenceArchiveHome missing ${token}`);
      }
    }

    // SiteHeader is live, but it is now the marketing header: the consumer
    // simplicity nav it used to render retired with the consumer routes. The
    // marketing-nav invariant is enforced by checkSiteHeaderNav instead.
    const header = fs.readFileSync(path.join(ROOT, "apps/web/components/SiteHeader.tsx"), "utf8");
    const simplicityNav = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/product/simplicity-mode.ts"),
      "utf8",
    );
    // SIMPLICITY_PRIMARY_NAV is deliberately empty and deprecated — web no
    // longer hosts consumer navigation. Requiring an Archive link in it asserts
    // the retired surface. The assertion is kept but inverted so it re-arms by
    // itself: the moment the nav is repopulated it must link Archive again.
    const simplicityNavEmpty = /SIMPLICITY_PRIMARY_NAV\s*=\s*\[\s*\]/.test(simplicityNav);
    if (!simplicityNavEmpty && !simplicityNav.includes('href: "/archive-belief"')) {
      fail("simplicity-mode must link Archive");
    }
    if (simplicityNavEmpty && !/@deprecated/.test(simplicityNav)) {
      fail(
        "SIMPLICITY_PRIMARY_NAV is empty but no longer marked @deprecated — " +
          "either restore consumer nav or keep the deprecation note explaining why it is empty",
      );
    }
    if (header.includes("TheoryUpdatesNav")) {
      fail("TheoryUpdatesNav must not be in primary SiteHeader");
    }

    const simplCopy = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/product/product-simplification-copy.ts"),
      "utf8",
    );
    const accountNavDeferred = deferRetiredWebSurface(
      "apps/web/components/account/AccountSecondaryNav.tsx",
      fail,
    );
    const accountNav = accountNavDeferred
      ? ""
      : fs.readFileSync(path.join(ROOT, "apps/web/components/account/AccountSecondaryNav.tsx"), "utf8");
    for (const label of ["Evidence for belief", "Archive Beliefs", "Reflection Log", "Changes"]) {
      if (!simplCopy.includes(label)) fail(`product-simplification-copy missing ${label}`);
      if (!accountNavDeferred && !accountNav.includes("NAV_")) {
        fail("AccountSecondaryNav must use simplification nav constants");
      }
    }

    // Retargeted at the live mobile sources. The nav labels moved out of
    // main_shell.dart — it now renders `destination.label` from the
    // PrimaryDestination model — and the route registry moved out of
    // app_router.dart, so both assertions were matching on strings that had
    // relocated rather than on surfaces that had regressed.
    //
    // apps/mobile is the consumer product, so this is the restraint invariant
    // worth keeping: it protects the live nav rather than a retired web one.
    const mobileNavSource = "apps/mobile/lib/router/primary_destination.dart";
    if (!fs.existsSync(path.join(ROOT, mobileNavSource))) {
      fail(`${mobileNavSource} is missing — mobile primary nav is unverifiable`);
    } else {
      const destinations = fs.readFileSync(path.join(ROOT, mobileNavSource), "utf8");
      const navLabels = [...destinations.matchAll(/^\s*label:\s*'([^']+)'/gm)].map((m) => m[1]);

      if (navLabels.length === 0) {
        fail(`${mobileNavSource} declares no primary destinations — refusing to pass vacuously`);
      }
      for (const label of ["Record", "Archive", "Account"]) {
        if (!navLabels.includes(label)) fail(`mobile nav missing ${label}`);
      }
      for (const forbidden of ["Journal", "Blind Spots"]) {
        if (navLabels.includes(forbidden)) {
          fail(`mobile primary nav must not include ${forbidden}`);
        }
      }
    }

    const mobileRouterDir = path.join(ROOT, "apps/mobile/lib/router");
    const routerSources = fs.existsSync(mobileRouterDir)
      ? fs
          .readdirSync(mobileRouterDir)
          .filter((f) => f.endsWith(".dart"))
          .map((f) => fs.readFileSync(path.join(mobileRouterDir, f), "utf8"))
          .join("\n")
      : "";
    if (!routerSources) {
      fail("apps/mobile/lib/router has no Dart sources — mobile routes are unverifiable");
    } else {
      if (!routerSources.includes("blind-spots")) fail("mobile must keep /blind-spots route");
      if (!routerSources.includes("archive-belief")) fail("mobile must keep archive-belief route");
    }

    const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
    if (!pkg.scripts["validate:restraint"]) {
      fail("package.json missing validate:restraint");
    }

    // These five were consumer web routes. They were retired to
    // apps/web/archived-consumer-routes, not deleted, and the equivalent
    // surfaces now live in apps/mobile. Each is deferred under the
    // both-directions rule rather than asserted against a directory that no
    // longer holds consumer routes.
    function mustNotDeleteRoutes() {
      const liveRoutes = fs
        .readdirSync(path.join(ROOT, "apps/web/app"), { recursive: true })
        .filter((f) => String(f).endsWith("page.tsx") || String(f).endsWith("route.ts"));

      for (const route of ["/blind-spots", "/theories", "/memory", "/updates", "/discover"]) {
        const needle = route.slice(1);
        if (liveRoutes.some((r) => String(r).includes(needle))) continue;
        deferRetiredWebSurface(`apps/web/app/${needle}/page.tsx`, fail);
      }
    }

    mustNotDeleteRoutes();

    const { buildArchiveProductObject } = await import("../packages/shared/lib/product/archive-product-model.ts");
    const { buildSurfaceAuditReport } = await import("../packages/shared/lib/product/surface-audit.ts");
    const { buildProductSimplificationReport } = await import(
      "../packages/shared/lib/internal/product-simplification-report.ts"
    );

    assert.ok(buildArchiveProductObject);

    // `primary.length >= 1` asserted that web had a primary consumer surface.
    // By contract (packages/shared/lib/site/web-public-production-routes.ts)
    // web is marketing, legal, support and beta only, and the primary consumer
    // surface is the mobile nav asserted above — so that assertion could never
    // hold again. What is still worth enforcing is that the audit actually
    // covers the live public route contract instead of auditing nothing.
    const { WEB_PUBLIC_PRODUCTION_ROUTES } = await import(
      "../packages/shared/lib/site/web-public-production-routes.ts"
    );
    const auditReport = buildSurfaceAuditReport();
    const auditedRoutes = new Set([
      ...auditReport.primary,
      ...auditReport.supporting,
      ...auditReport.utility,
      ...auditReport.internal,
    ].map((e) => e.route));

    assert.ok(
      WEB_PUBLIC_PRODUCTION_ROUTES.length > 0,
      "web public production route contract is empty — surface audit would be vacuous",
    );
    for (const route of WEB_PUBLIC_PRODUCTION_ROUTES) {
      assert.ok(
        auditedRoutes.has(route),
        `surface audit does not cover public production route ${route}`,
      );
    }

    assert.ok(buildProductSimplificationReport().oneLiner.includes("archive"));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkRestraint() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const SCAN_DIRS = ["apps/web/app", "apps/web/components", "packages/shared/lib"];

    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      `${path.sep}api${path.sep}`,
      "apps/web/app/safety",
      "apps/web/app/privacy",
      "apps/web/app/terms",
      "apps/web/app/contact",
      "apps/web/app/launch",
      "apps/web/app/welcome",
      "apps/web/app/how-it-works",
      "apps/web/app/privacy-simple",
      "packages/shared/lib/debug",
      "packages/shared/lib/validation",
      "packages/shared/lib/intentions",
      "packages/shared/lib/marketing",
      "packages/shared/lib/social-proof",
      "packages/shared/lib/sharing",
      "packages/shared/lib/memory/memory-compounding.ts",
      "packages/shared/lib/memory/slow-realizations.ts",
      "packages/shared/lib/refinement/revisit-sequencing.ts",
      "packages/shared/lib/refinement/durable-callbacks.ts",
      "packages/shared/lib/archive/",
      "packages/shared/lib/research/",
      "packages/shared/lib/monetization/",
      "packages/shared/lib/pilot/",
      "packages/shared/lib/integrity/",
      "packages/shared/lib/identity/",
      "packages/shared/lib/personalization/",
      "packages/shared/lib/territories/",
      "packages/shared/lib/atmosphere/",
      "packages/shared/lib/photo-storage.ts",
      "packages/shared/lib/restraint/",
      "packages/shared/lib/memory-language.ts",
      "packages/shared/lib/product/recognition-copy.ts",
      "packages/shared/lib/onboarding/",
      "packages/shared/lib/resurfacing/emotional-specificity.ts",
      "packages/shared/lib/resurfacing/genericity-filter.ts",
      "packages/shared/lib/refinement/callback-deduplication.ts",
      "packages/shared/lib/refinement/callback-suppression.ts",
      "packages/shared/lib/revisit/resurfacing-copy.ts",
      "packages/shared/lib/refinement/anti-template.ts",
      "packages/shared/lib/refinement/rarity-preservation.ts",
      "packages/shared/lib/refinement/permanent-callbacks.ts",
      "packages/shared/lib/roundups/roundup-quality.ts",
      "packages/shared/lib/roundups/roundup-observation.ts",
      "packages/shared/lib/tester-onboarding-copy.ts",
      "packages/shared/lib/patterns/pattern-engine.ts",
      "packages/shared/lib/patterns/continuity-engine.ts",
      "packages/shared/lib/retention-metrics.ts",
      "packages/shared/lib/retention/retention-loops.ts",
      "packages/shared/lib/retention/gentle-return-prompts.ts",
      "packages/shared/lib/launch-checklist.ts",
      "packages/shared/lib/conversation/followup-prompts.ts",
      "packages/shared/lib/refinement/callback-tuning.ts",
      "packages/shared/lib/revisit/resurfacing-why-now.ts",
      "packages/shared/lib/retention/first-week.ts",
      "packages/shared/lib/retention/recurrence-density.ts",
      "scripts/",
    ];

    /** Routes the marketing header may link: marketing, legal, support, beta. */
    const MARKETING_NAV_ALLOWED_HREFS = new Set([
      "/",
      "/beta",
      "/privacy",
      "/privacy-simple",
      "/terms",
      "/safety",
      "/contact",
      "/welcome",
      "/how-it-works",
    ]);

    const ALLOWED_LINK_PREFIXES = [
      "/",
      "/memory",
      "/timeline",
      "/weekly",
      "/monthly",
      "/seasons",
      "/bookmarks",
      "/open-loops",
      "/blind-spots",
      "/theories",
      "/discover",
      "/threads",
      "/reminders",
      "/pricing",
      "/settings",
      "/account",
      "/archive",
      "/export",
      "/search",
      "/journal",
      "/roundups",
      "/intentions",
      "/privacy",
      "/terms",
      "/safety",
      "/contact",
      "/welcome",
      "/how-it-works",
      "/privacy-simple",
      "/entry/",
      "/demo",
      "/#",
    ];

    const FORBIDDEN_LINK_PREFIXES = [
      "/dashboard",
      "/coach",
      "/analytics",
      "/achievements",
      "/insights-engine",
      "/performance",
      "/internal/",
    ];

    const BANNED_PHRASES = [
      { re: /\bdashboard\b/i, label: "dashboard" },
      { re: /\bcoach\b/i, label: "coach" },
      { re: /\bAI coach\b/i, label: "AI coach" },
      { re: /\bassistant\b/i, label: "assistant" },
      { re: /\bproductivity\b/i, label: "productivity" },
      { re: /\boptimize\b/i, label: "optimize" },
      { re: /\btherapy bot\b/i, label: "therapy bot" },
      { re: /\bmental health diagnosis\b/i, label: "mental health diagnosis" },
      { re: /\bperformance score\b/i, label: "performance score" },
      { re: /\bgamified\b/i, label: "gamified" },
      { re: /\bachievement\b/i, label: "achievement" },
      { re: /\bstreak badge\b/i, label: "streak badge" },
      { re: /\banalytics dashboard\b/i, label: "analytics dashboard" },
      { re: /\binsight engine\b/i, label: "insight engine" },
      { re: /\bpattern engine\b/i, label: "pattern engine" },
      { re: /\baction plan\b/i, label: "action plan" },
      { re: /\bgoal dashboard\b/i, label: "goal dashboard" },
      { re: /\bproductivity score\b/i, label: "productivity score" },
      { re: /\bhabit completion\b/i, label: "habit completion" },
      { re: /\bkpi\b/i, label: "KPI" },
      { re: /\bsmart goal\b/i, label: "SMART goal" },
      { re: /\bcoaching plan\b/i, label: "coaching plan" },
      { re: /\bmemory intelligence\b/i, label: "memory intelligence" },
      { re: /\breflective mirror\b/i, label: "reflective mirror" },
      { re: /\bemotional continuity\b/i, label: "emotional continuity" },
      { re: /\bliving resurfacing\b/i, label: "living resurfacing" },
      { re: /\bvoice identity\b/i, label: "voice identity" },
      { re: /\bemotional chapter\b/i, label: "emotional chapter" },
      { re: /\bgently return\b/i, label: "gently return" },
      { re: /\bintelligence layer\b/i, label: "intelligence layer" },
      { re: /\bself-awareness\b/i, label: "self-awareness" },
      { re: /\bdiscover patterns\b/i, label: "discover patterns" },
      { re: /\bmindfulness\b/i, label: "mindfulness" },
      { re: /\b(?:healing|growth|inner|self-care)\s+journey\b/i, label: "wellness journey" },
      { re: /\byour journey\b/i, label: "your journey" },
      { re: /\bgrowth mindset\b/i, label: "growth mindset" },
      { re: /\binsights summary\b/i, label: "insights summary" },
      { re: /\bweekly intelligence\b/i, label: "weekly intelligence" },
      { re: /\bsilence intelligence\b/i, label: "silence intelligence" },
      { re: /\bAI journal\b/i, label: "AI journal" },
      { re: /\bcoaching\b/i, label: "coaching" },
      { re: /\btherapy-like\b/i, label: "therapy-like" },
      { re: /\bhold space\b/i, label: "hold space" },
      { re: /\binner work\b/i, label: "inner work" },
      { re: /\bbreakthrough moment\b/i, label: "breakthrough moment" },
    ];

    const CHART_DASHBOARD_PHRASES = [
      { re: /\b(?:bar|line|pie|area)\s+chart\b/i, label: "chart wording" },
      { re: /\bdata visualization\b/i, label: "data visualization" },
      { re: /\bmetrics dashboard\b/i, label: "metrics dashboard" },
      { re: /\bretention dashboard\b/i, label: "retention dashboard" },
      { re: /\bkpi\b/i, label: "KPI wording" },
      { re: /\bscoreboard\b/i, label: "scoreboard" },
    ];

    const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);
    const MAX_CARDS_PER_PAGE = 4;
    const SITE_HEADER = path.join(ROOT, "apps/web/components/SiteHeader.tsx");

    function shouldSkip(filePath) {
      const rel = path.relative(ROOT, filePath);
      return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
    }

    function walk(dir, out = []) {
      if (!fs.existsSync(dir)) return out;
      for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (shouldSkip(full)) continue;
        const stat = fs.statSync(full);
        if (stat.isDirectory()) walk(full, out);
        else if (EXT.has(path.extname(name))) out.push(full);
      }
      return out;
    }

    function isCommentLine(trimmed) {
      return (
        trimmed.startsWith("//") ||
        trimmed.startsWith("*") ||
        trimmed.startsWith("/*") ||
        trimmed.endsWith("*/")
      );
    }

    function isValidationScriptLine(trimmed) {
      return (
        trimmed.includes("validate:restraint") ||
        trimmed.includes("validate:quiet-copy") ||
        trimmed.includes("validate-product-restraint") ||
        trimmed.includes("validate-onboarding-restraint") ||
        trimmed.includes("BANNED_PHRASES") ||
        trimmed.includes("FORBIDDEN_RE") ||
        trimmed.includes("ONBOARDING_BLOCKED")
      );
    }

    function isImportOrTypeLine(trimmed) {
      return (
        trimmed.startsWith("import ") ||
        trimmed.startsWith("export type ") ||
        trimmed.startsWith("export interface ") ||
        trimmed.startsWith("type ") ||
        trimmed.startsWith("interface ")
      );
    }

    function isBannedPhraseAllowed(line, label) {
      if (isImportOrTypeLine(line.trim())) {
        if (label === "wellness journey" && /archive-growth|silence-intelligence/i.test(line)) {
          return true;
        }
        if (label === "silence intelligence" && /silence-intelligence/i.test(line)) return true;
      }
      if (label === "coaching" && /\bnot coaching\b/i.test(line)) return true;
      if (label === "coaching" && /\bdisguised coaching\b/i.test(line)) return true;
      if (label === "AI journal" && /\bnot an ai journal\b/i.test(line)) return true;
      if (label === "coach" && /\bnot coaching\b/i.test(line)) return true;
      if (label === "wellness journey" && /^(import |export )/.test(line.trim())) return true;
      if (label === "silence intelligence" && /silence-intelligence|SilenceIntelligence|getSilenceIntelligence|recordReflectionDuringSilence|shouldSuppressSilenceIntelligence|pickSilenceIntelligence|buildSilenceIntelligence|setSilenceIntelligence|silenceIntelligence\b/i.test(line)) {
        return true;
      }
      if (label === "mental health diagnosis" && /\bnot a (?:mental health )?diagnosis\b/i.test(line)) {
        return true;
      }
      if (label === "wellness journey" && /\/\\b|FORBIDDEN|THERAPY_RE|blocked|filter|test\(/i.test(line)) {
        return true;
      }
      if (label === "hold space" && /\/\\b|FORBIDDEN|blocked|filter|test\(/i.test(line)) {
        return true;
      }
      return false;
    }

    function pushViolation(violations, filePath, lineNo, rule, detail, line) {
      violations.push({
        filePath,
        lineNo,
        rule,
        detail,
        line: line.trim().slice(0, 120),
      });
    }

    // BANNED_PHRASES are user-facing *copy* rules ("dashboard", "coach",
    // "assistant"). They were being applied to every file in SCAN_DIRS,
    // including all of `packages/shared/lib`, where the same words occur as
    // ordinary server identifiers — `issueCoachConsentToken`, `coachId`,
    // `kind: "dashboard"` in the internal surface registry. That produced 110
    // findings about code that renders no copy at all.
    //
    // Every other check in this file already restricts itself to UI surfaces
    // via the same `isUserFacing` shape used below; this one simply never did.
    // Scoping it the same way is the fix — the phrases it flags in server code
    // are correct identifiers, not copy violations.
    function isUiCopySurface(filePath) {
      const inApp =
        filePath.includes(`${path.sep}app${path.sep}`) &&
        filePath.endsWith("page.tsx");
      const inComponents = filePath.includes(`${path.sep}components${path.sep}`);
      return (
        (inApp || inComponents) && !filePath.includes(`${path.sep}debug${path.sep}`)
      );
    }

    function checkBannedPhrases(content, filePath, violations) {
      if (!isUiCopySurface(filePath)) return;

      const lines = content.split("\n");
      lines.forEach((line, i) => {
        const trimmed = line.trim();
        if (!trimmed || isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;

        for (const { re, label } of BANNED_PHRASES) {
          if (re.test(line) && !isBannedPhraseAllowed(line, label)) {
            pushViolation(violations, filePath, i + 1, "banned phrase", label, line);
          }
        }
      });
    }

    function checkChartDashboardWording(content, filePath, violations) {
      const isUserPage =
        filePath.includes(`${path.sep}app${path.sep}`) &&
        filePath.endsWith("page.tsx") &&
        !filePath.includes(`${path.sep}debug${path.sep}`);

      if (!isUserPage) return;

      const lines = content.split("\n");
      lines.forEach((line, i) => {
        const trimmed = line.trim();
        if (!trimmed || isCommentLine(trimmed) || isValidationScriptLine(trimmed)) return;

        for (const { re, label } of CHART_DASHBOARD_PHRASES) {
          if (re.test(line)) {
            pushViolation(violations, filePath, i + 1, "chart/dashboard wording", label, line);
          }
        }
      });
    }

    function extractHrefLiterals(content) {
      const hrefs = new Set();

      const quoted = /href=["']([^"'#]+)["']/g;
      let match;
      while ((match = quoted.exec(content)) !== null) {
        hrefs.add(match[1]);
      }

      const navConst = /href:\s*"(\/[^"]+)"/g;
      while ((match = navConst.exec(content)) !== null) {
        hrefs.add(match[1]);
      }

      return [...hrefs];
    }

    function isAllowedProductLink(href) {
      if (FORBIDDEN_LINK_PREFIXES.some((prefix) => href.startsWith(prefix))) return false;
      return ALLOWED_LINK_PREFIXES.some((prefix) => href === prefix || href.startsWith(prefix));
    }

    // Retargeted at the live surface. This used to require the header to link
    // /journal, /intentions, /insights, /search and /pricing — consumer routes
    // retired to apps/web/archived-consumer-routes. Production web is now
    // marketing, legal, support and beta, and apps/mobile is the consumer
    // product, so the old assertion demanded the exact opposite of the stated
    // intent and failed five times on a header that is correct.
    //
    // The invariant worth keeping is the restraint one: the marketing header
    // must not grow consumer product navigation. That is checked against the
    // nav source the header actually renders, so it protects the live surface
    // and starts failing the moment a product route is linked from marketing.
    function checkSiteHeaderNav(content, filePath, violations) {
      if (filePath !== SITE_HEADER) return;

      if (!content.includes("WEB_MARKETING_NAV")) {
        pushViolation(
          violations,
          filePath,
          0,
          "nav regression",
          "SiteHeader must render WEB_MARKETING_NAV",
          "WEB_MARKETING_NAV",
        );
        return;
      }

      const navPath = path.join(ROOT, "packages/shared/lib/site/web-marketing-nav.ts");
      if (!fs.existsSync(navPath)) {
        pushViolation(
          violations,
          filePath,
          0,
          "nav regression",
          "web-marketing-nav.ts is missing — header nav is unverifiable",
          navPath,
        );
        return;
      }

      const navSource = fs.readFileSync(navPath, "utf8");
      const navHrefs = [...navSource.matchAll(/href:\s*"(\/[^"]*)"/g)].map((m) => m[1]);

      if (navHrefs.length === 0) {
        pushViolation(
          violations,
          filePath,
          0,
          "nav regression",
          "WEB_MARKETING_NAV declares no links — refusing to pass this check vacuously",
          navPath,
        );
      }

      for (const href of navHrefs) {
        if (!MARKETING_NAV_ALLOWED_HREFS.has(href)) {
          pushViolation(
            violations,
            filePath,
            0,
            "non-essential nav",
            `marketing header links consumer product route: ${href}`,
            `{ href: "${href}" }`,
          );
        }
      }

      for (const href of extractHrefLiterals(content)) {
        if (href === "/") continue;
        if (!MARKETING_NAV_ALLOWED_HREFS.has(href)) {
          pushViolation(
            violations,
            filePath,
            0,
            "non-essential nav",
            `unexpected hard-coded header link: ${href}`,
            `<Link href="${href}">`,
          );
        }
      }
    }

    function checkPageNavLinks(content, filePath, violations) {
      const isUserPage =
        filePath.includes(`${path.sep}app${path.sep}`) &&
        filePath.endsWith("page.tsx") &&
        !filePath.includes(`${path.sep}debug${path.sep}`);

      if (!isUserPage || filePath === SITE_HEADER) return;

      const hrefs = extractHrefLiterals(content);
      for (const href of hrefs) {
        if (href.startsWith("http")) continue;
        if (isAllowedProductLink(href)) continue;
        pushViolation(
          violations,
          filePath,
          0,
          "non-essential nav",
          `product page links to non-essential route: ${href}`,
          `<Link href="${href}">`,
        );
      }
    }

    function checkDenseCardSections(content, filePath, violations) {
      const isUserPage =
        filePath.includes(`${path.sep}app${path.sep}`) &&
        filePath.endsWith("page.tsx") &&
        !filePath.includes(`${path.sep}debug${path.sep}`);

      if (!isUserPage) return;

      const cardCount = (content.match(/<Card[\s>]/g) ?? []).length;
      const gridCardSection = /<div[^>]*className="[^"]*grid-cols-(?:3|4)[^"]*"[^>]*>[\s\S]{0,400}<Card[\s>]/i.test(
        content,
      );

      if (cardCount > MAX_CARDS_PER_PAGE) {
        pushViolation(
          violations,
          filePath,
          0,
          "dense cards",
          `${cardCount} Card sections (max ${MAX_CARDS_PER_PAGE})`,
          "<Card …>",
        );
      } else if (gridCardSection && cardCount >= 3) {
        pushViolation(
          violations,
          filePath,
          0,
          "dense cards",
          "grid of cards on user-facing page",
          'className="…grid-cols-…" with Card',
        );
      }
    }

    /** Product surfaces for discovery-loop integration audit (see validate-discovery-loop.mjs). */
    const DISCOVERY_LOOP_SCAN = [
      "apps/web/app/discover",
      "apps/web/app/theories",
      "apps/web/app/blind-spots",
      "apps/web/app/memory",
      "apps/web/components/discover",
      "apps/web/components/theories",
      "apps/web/components/blind-spots",
      "apps/web/components/internal/TheoryDiscoveryPanel.tsx",
      "apps/web/components/internal/TheoryVolatilityPanel.tsx",
      "apps/web/components/internal/SelfRecognitionIngredientsPanel.tsx",
      "packages/shared/lib/discover",
      "packages/shared/lib/theories",
      "packages/shared/lib/insights",
      "packages/shared/lib/blind-spots/mini-wow.ts",
      "packages/shared/lib/blind-spots/mini-wow-copy.ts",
      "packages/shared/types/theory.ts",
      "packages/shared/types/mini-wow.ts",
      "packages/shared/types/self-recognition-ingredients.ts",
      "packages/shared/types/evidence-feed.ts",
    ];

    const discoveryLoopScope = process.env.RESTRAINT_SCOPE === "discovery-loop";

    function collectScanFiles() {
      if (discoveryLoopScope) {
        const files = [];
        for (const rel of DISCOVERY_LOOP_SCAN) {
          const full = path.join(ROOT, rel);
          if (!fs.existsSync(full)) continue;
          const stat = fs.statSync(full);
          if (stat.isDirectory()) walk(full, files);
          else if (EXT.has(path.extname(full))) files.push(full);
        }
        return files;
      }
      return SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
    }

    const files = collectScanFiles();
    const violations = [];

    for (const file of files) {
      const content = fs.readFileSync(file, "utf8");
      checkBannedPhrases(content, file, violations);
      checkChartDashboardWording(content, file, violations);
      if (!discoveryLoopScope) {
        checkSiteHeaderNav(content, file, violations);
        checkPageNavLinks(content, file, violations);
        checkDenseCardSections(content, file, violations);
      }
    }

    // Narrowing the copy scan to UI surfaces above means it now depends on
    // those surfaces existing. If apps/web is ever reorganised again this
    // check would read zero files and report success, which is the failure
    // mode this repo has already been bitten by three times.
    const copySurfaces = files.filter((f) => isUiCopySurface(f));
    if (copySurfaces.length === 0) {
      fail(
        "banned-phrase copy scan matched no UI surfaces under " +
          `${SCAN_DIRS.join(", ")} — refusing to report success without reading anything`,
      );
    }



    const productCopyPath = path.join(ROOT, "packages/shared/lib/product-copy.ts");
    if (!fs.existsSync(productCopyPath)) fail("missing lib/product-copy.ts");
    const productCopy = fs.readFileSync(productCopyPath, "utf8");
    const productCopyRequired = [
      ["Your words stay yours", "RECOGNITION_COPY.notAiJournal"],
      ["You said this before", "RECOGNITION_COPY.wedge", "brings back what you already said", "brings back phrases you already spoke"],
      ["Words you forgot you had already spoken."],
      ["This came back.", "MEMORY_LANGUAGE.thisCameBack"],
      ["Your own words came back.", "MEMORY_LANGUAGE.wordsReturned"],
      ["You used similar words before."],
      ["This concern showed up again."],
      ["Hearing your own voice makes the return harder to shrug off."],
    ];
    for (const alternatives of productCopyRequired) {
      if (!alternatives.some((token) => productCopy.includes(token))) fail(`product-copy missing wedge line: ${alternatives[0]}`);
    }

    const scopeLabel = discoveryLoopScope ? "discovery-loop surfaces" : "full product";
    for (const v of violations) fail(formatViolation(v));
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkArchiveSilence() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    function read(rel) {
      return fs.readFileSync(path.join(ROOT, rel), "utf8");
    }

    function mustExist(rel) {
      if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
    }

    // The shared library half of this invariant is still live and still
    // enforced below. Only the consumer-web rendering half is deferred.
    const required = [
      "packages/shared/types/archive-silence.ts",
      "packages/shared/lib/archive/archive-silence.ts",
    ];

    for (const rel of required) mustExist(rel);

    const cardDeferred = deferRetiredWebSurface(
      "apps/web/components/archive/ArchiveSilenceCard.tsx",
      fail,
    );

    const lib = read("packages/shared/lib/archive/archive-silence.ts");
    for (const phrase of [
      "ARCHIVE_SILENCE_TITLE",
      "buildArchiveSilenceView",
      "readBeliefTimelineHistory",
      "buildPhraseMemory",
      "belief_evidence_gap",
      "life_area_absent",
      "pattern_fading",
      "The archive has not seen evidence for this belief",
      "The archive has not seen evidence from",
      "This pattern may be fading.",
      "assertNoCertaintyLanguage",
      "RESURFACING_MIN_ABSENCE_DAYS",
    ]) {
      if (!lib.includes(phrase)) fail(`archive-silence missing: ${phrase}`);
    }

    const forbidden = [
      /\bcertainly\b/i,
      /\bdefinitely\b/i,
      /\bproven\b/i,
      /\bguaranteed\b/i,
      /\bwithout doubt\b/i,
    ];
    for (const pattern of forbidden) {
      if (pattern.test(lib)) fail(`archive-silence contains forbidden certainty language`);
    }

    if (!cardDeferred) {
      const card = read("apps/web/components/archive/ArchiveSilenceCard.tsx");
      if (!card.includes('data-testid="archive-silence-card"')) {
        fail("ArchiveSilenceCard missing test id");
      }
      if (!card.includes("buildArchiveSilenceView")) {
        fail("ArchiveSilenceCard must call buildArchiveSilenceView");
      }

      const surfaces = [
        ["apps/web/components/archive/ArchiveCommandCenter.tsx", "Archive"],
        ["apps/web/components/archive/BeliefDossier.tsx", "Belief Dossier"],
        ["apps/web/app/discover/page.tsx", "Discover"],
      ];

      for (const [file, label] of surfaces) {
        const src = read(file);
        if (!src.includes("ArchiveSilenceCard")) {
          fail(`${label} (${file}) must render ArchiveSilenceCard`);
        }
      }
    }

    const pkg = JSON.parse(read("package.json"));
    if (!pkg.scripts?.["validate:restraint"]) {
      fail("package.json missing validate:restraint");
    }


    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkOfflineRecordingCopy() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const failures = [];

    const offline = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/reliability/offline-transcription.ts"),
      "utf8",
    );
    if (!offline.includes("Saved on this device. Transcription needs internet.")) {
      failures.push("offline-transcription must use calm saved copy");
    }

    // The copy modules below are live shared code and stay enforced. The
    // Recorder assertions are deferred: the consumer web recorder was retired
    // with the rest of the consumer web product, and audio capture now lives
    // in apps/mobile, whose own gates cover it.
    const recorderDeferred = deferRetiredWebSurface(
      "apps/web/components/Recorder.tsx",
      (msg) => failures.push(msg),
    );

    const mic = fs.readFileSync(path.join(ROOT, "packages/shared/lib/capture/mic-permission-copy.ts"), "utf8");
    if (!mic.includes("Allow microphone to record here")) {
      failures.push("mic-permission-copy must include allow line");
    }

    if (!recorderDeferred) {
      const recorder = fs.readFileSync(path.join(ROOT, "apps/web/components/Recorder.tsx"), "utf8");
      if (recorder.includes("Failed to fetch")) {
        failures.push("Recorder must not show raw Failed to fetch");
      }
      if (!recorder.includes("OFFLINE_TRANSCRIPTION_SAVED_COPY") || !recorder.includes("saveOfflineRecordingDraft")) {
        failures.push("Recorder must wire offline transcription fallback");
      }
      if (!recorder.includes("MicPermissionPanel")) {
        failures.push("Recorder must use MicPermissionPanel");
      }
    }


    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}