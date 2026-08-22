#!/usr/bin/env node
/**
 * Unified resurfacing validation — combines 12 former scripts:
 *   fatigue, variety, frequency, open-loops (+tests, +performance, +render),
 *   restraint, specificity, confidence, timing, evidence.
 *
 * Run all:  npm run validate:resurfacing
 * Run one:  RESURFACING_CHECK=specificity npm run validate:resurfacing
 */
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { deferRetiredWebSurface, readOrDefer } from "./lib/retired-web-surface.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

/**
 * `REQUIRED`/`SCANNED` lists in this file mix live shared modules with consumer
 * web components retired to `apps/web/archived-*`. Live entries stay asserted;
 * retired ones are deferred under the both-directions rule in
 * ./lib/retired-web-surface.mjs.
 */
function requireOrDeferAll(list, fail) {
  return list.filter((rel) => {
    if (fs.existsSync(path.join(ROOT, rel))) return true;
    if (rel.startsWith("apps/web/")) {
      deferRetiredWebSurface(rel, fail);
      return false;
    }
    fail(`missing ${rel}`);
    return false;
  });
}

function formatViolation(v) {
  const filePath = v.filePath ?? v.file;
  const lineNo = v.lineNo ?? (typeof v.line === "number" ? v.line : 0);
  if (filePath && typeof filePath === "string") {
    const rel = path.relative(ROOT, filePath);
    const loc = lineNo > 0 ? `${rel}:${lineNo}` : rel;
    const label = v.label ?? v.word ?? v.rule ?? "violation";
    const text = v.text ?? (typeof v.line === "string" ? v.line : "") ?? v.detail ?? "";
    return `${loc} [${label}] ${text}`.trim();
  }
  return String(v);
}

const CHECKS = [
  { name: "fatigue", run: checkFatigue },
  { name: "variety", run: checkVariety },
  { name: "frequency", run: checkFrequency },
  { name: "open-loops", run: checkOpenLoops },
  { name: "open-loops-tests", run: checkOpenLoopsTests },
  { name: "open-loops-performance", run: checkOpenLoopsPerformance },
  { name: "open-loop-render", run: checkOpenLoopRender },
  { name: "restraint", run: checkRestraint },
  { name: "specificity", run: checkSpecificity },
  { name: "confidence", run: checkConfidence },
  { name: "timing", run: checkTiming },
  { name: "evidence", run: checkEvidence },
];

async function main() {
  const only = process.env.RESURFACING_CHECK?.trim();
  const selected = only ? CHECKS.filter((c) => c.name === only) : CHECKS;
  if (only && selected.length === 0) {
    console.error(`Unknown RESURFACING_CHECK="${only}". Valid: ${CHECKS.map((c) => c.name).join(", ")}`);
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
    console.error("\nvalidate:resurfacing failed");
    process.exit(1);
  }
  console.log(`validate:resurfacing passed (${selected.length} check(s))`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

async function checkFatigue() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const REQUIRED = [
      "packages/shared/lib/resurfacing/resurfacing-fatigue.ts",
      "packages/shared/lib/resurfacing/behavioral-ranking.ts",
      "packages/shared/lib/resurfacing/return-modes.ts",
    ];


    requireOrDeferAll(REQUIRED, (m) => failures.push(m));

    const fatigue = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/resurfacing/resurfacing-fatigue.ts"),
      "utf8",
    );

    for (const fn of [
      "recordResurfacingIgnored",
      "recordResurfacingOpenedWithoutReflection",
      "recordResurfacingDismissed",
      "shouldSuppressResurfacingNote",
      "getResurfacingFatiguePenalty",
    ]) {
      if (!fatigue.includes(fn)) {
        failures.push(`resurfacing-fatigue must export ${fn}`);
      }
    }

    const ranking = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/resurfacing/behavioral-ranking.ts"),
      "utf8",
    );
    if (!ranking.includes("applyBehavioralRankingBoost")) {
      failures.push("behavioral-ranking must export applyBehavioralRankingBoost");
    }

    const tuning = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/refinement/callback-tuning.ts"),
      "utf8",
    );
    if (!tuning.includes("shouldSuppressResurfacingNote")) {
      failures.push("callback-tuning must apply resurfacing fatigue suppression");
    }
    if (!tuning.includes("filterCallbacksByModeDiversity")) {
      failures.push("callback-tuning must apply return-mode diversity");
    }


    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkVariety() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const REQUIRED = [
      "packages/shared/lib/resurfacing/return-modes.ts",
      "packages/shared/lib/resurfacing/resurfacing-mode-observation.ts",
      "packages/shared/lib/resurfacing/resurfacing-variety-report.ts",
      "packages/shared/lib/resurfacing/resurfacing-frequency.ts",
      "packages/shared/lib/resurfacing/resurfacing-change-detection.ts",
      "packages/shared/lib/resurfacing/resurfacing-natural-voice.ts",
      "packages/shared/types/resurfacing-variety.ts",
      "apps/web/app/internal/resurfacing-variety/page.tsx",
      "apps/web/components/internal/ResurfacingVarietyPanel.tsx",
    ];

    const BANNED = [
      /\btherapy\b/i,
      /\bcoach\b/i,
      /\byou should\b/i,
      /\binspirational\b/i,
      /\bhealing journey\b/i,
    ];


    requireOrDeferAll(REQUIRED, (m) => failures.push(m));

    const modes = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/resurfacing/return-modes.ts"),
      "utf8",
    );
    for (const token of [
      "exact_echo",
      "contradiction",
      "silence_gap",
      "escalation",
      "recurrence_observation",
      "filterCallbacksByModeDiversity",
      "getReturnModeFatiguePenalty",
      "resurfacing_mode_shown",
    ]) {
      if (!modes.includes(token)) {
        failures.push(`return-modes missing ${token}`);
      }
    }

    const tuning = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/refinement/callback-tuning.ts"),
      "utf8",
    );
    if (!tuning.includes("filterCallbacksByModeDiversity")) {
      failures.push("callback-tuning must diversify by return mode");
    }

    const sideEffects = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/refinement/presentation-side-effects.ts"),
      "utf8",
    );
    if (!sideEffects.includes("observeResurfacingModeShown")) {
      failures.push("presentation-side-effects must track resurfacing_mode_shown");
    }

    const push = (m) => failures.push(m);
    const panel = readOrDefer("apps/web/components/internal/ResurfacingVarietyPanel.tsx", push);
    if (panel !== null) {
      for (const section of [
        "Mode distribution",
        "Repetition warnings",
        "Overused phrases",
        "cadence clustering",
        "Frequency restraint",
      ]) {
        if (!panel.includes(section) && !panel.toLowerCase().includes(section.toLowerCase())) {
          failures.push(`ResurfacingVarietyPanel missing ${section}`);
        }
      }
    }

    for (const rel of ["packages/shared/lib/resurfacing/return-modes.ts", "apps/web/components/internal/ResurfacingVarietyPanel.tsx"]) {
      const text = readOrDefer(rel, push);
      if (text === null) continue;
      for (const re of BANNED) {
        if (re.test(text)) failures.push(`${rel}: banned ${re}`);
      }
    }

    const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
    if (!pkg.includes("validate:resurfacing")) {
      failures.push("package.json must wire validate:resurfacing");
    }


    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkFrequency() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const REQUIRED = [
      "packages/shared/lib/resurfacing/resurfacing-frequency.ts",
      "packages/shared/lib/resurfacing/resurfacing-change-detection.ts",
      "packages/shared/lib/resurfacing/resurfacing-specificity-gate.ts",
      "packages/shared/lib/resurfacing/resurfacing-natural-voice.ts",
    ];


    requireOrDeferAll(REQUIRED, (m) => failures.push(m));

    const frequency = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/resurfacing/resurfacing-frequency.ts"),
      "utf8",
    );
    for (const fn of [
      "shouldReduceResurfacingFrequency",
      "shouldSuppressSimilarResurfacing",
      "shouldCooldownResurfacing",
      "shouldPreferMicFirstWithoutContinuityStack",
      "capHomepageResurfacingPresentation",
    ]) {
      if (!frequency.includes(fn)) {
        failures.push(`resurfacing-frequency must export ${fn}`);
      }
    }

    const tuning = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/refinement/callback-tuning.ts"),
      "utf8",
    );
    for (const token of [
      "shouldSuppressResurfacingByFrequency",
      "hasDetectableChange",
      "passesResurfacingSpecificityGate",
      "naturalizeResurfacingNote",
    ]) {
      if (!tuning.includes(token)) {
        failures.push(`callback-tuning must use ${token}`);
      }
    }

    const quiet = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/refinement/quiet-presentation.ts"),
      "utf8",
    );
    if (!quiet.includes("capHomepageResurfacingPresentation")) {
      failures.push("quiet-presentation must cap homepage resurfacing");
    }

    const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
    if (!pkg.includes("validate:resurfacing")) {
      failures.push("package.json must wire validate:resurfacing");
    }


    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkOpenLoops() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const REQUIRED_FILES = [
      "packages/shared/types/open-loop.ts",
      "packages/shared/lib/open-loops/open-loop-storage.ts",
      "packages/shared/lib/open-loops/unresolved-signals.ts",
      "packages/shared/lib/open-loops/open-loop-copy.ts",
      "packages/shared/lib/open-loops/open-loop-continuity.ts",
      "packages/shared/lib/open-loops/open-loop-resurfacing-lines.ts",
      "packages/shared/lib/open-loops/open-loop-activation.ts",
      "packages/shared/lib/open-loops/open-loop-activation-audit.ts",
      "packages/shared/lib/open-loops/open-loop-activation-debug.ts",
      "packages/shared/lib/open-loops/unresolved-cache.ts",
      "packages/shared/lib/open-loops/unresolved-detect-core.ts",
      "packages/shared/lib/open-loops/open-loop-performance.ts",
      "packages/shared/lib/open-loops/open-loop-defer.ts",
      "packages/shared/lib/runtime/render-safe.ts",
      "packages/shared/lib/runtime/read-model.ts",
      "packages/shared/lib/runtime/write-actions.ts",
      "packages/shared/lib/runtime/deferred-jobs.ts",
      "apps/web/app/internal/open-loop-performance/page.tsx",
      "packages/shared/lib/open-loops/open-loop-return-prompt.ts",
      "apps/web/app/internal/open-loop-activation/page.tsx",
      "packages/shared/lib/open-loops/open-loop-silence.ts",
      "packages/shared/lib/open-loops/emotional-shift.ts",
      "packages/shared/lib/open-loops/open-loop-readout.ts",
      "packages/shared/lib/open-loops/open-loop-observation.ts",
      "apps/web/app/internal/open-loops-readout/page.tsx",
      "apps/web/components/entry/OpenLoopNextStepPrompt.tsx",
      "apps/web/components/open-loops/OpenLoopCard.tsx",
      "apps/web/components/open-loops/OpenLoopsList.tsx",
      "apps/web/app/open-loops/page.tsx",
    ];

    const SKIP_PATH_PARTS = [
      `${path.sep}debug${path.sep}`,
      "apps/web/app/internal/open-loops-readout/",
      "packages/shared/lib/open-loops/",
      "apps/web/components/entry/OpenLoopNextStepPrompt.tsx",
      "apps/web/components/open-loops/",
      "apps/web/app/open-loops/",
      "scripts/",
    ];

    const USER_FACING_BANNED = [
      { re: /\baction plan\b/i, label: "action plan" },
      { re: /\bcoaching plan\b/i, label: "coaching plan" },
      { re: /\b(?:we|you) should\b/i, label: "prescriptive should" },
      { re: /\btry this\b/i, label: "try this" },
      { re: /\bwellness\b/i, label: "wellness" },
      { re: /\btherapy\b/i, label: "therapy" },
      { re: /\bself-care\b/i, label: "self-care" },
      { re: /\bai[- ]generated\b/i, label: "AI-generated" },
      { re: /\brecommend(?:ation)?s?\b/i, label: "recommended" },
      { re: /\bcoping\b/i, label: "coping" },
      { re: /\bhealing journey\b/i, label: "healing journey" },
      { re: /\btask\b/i, label: "task" },
      { re: /\bproductivity\b/i, label: "productivity" },
      { re: /\bgoal tracking\b/i, label: "goal tracking" },
      { re: /\bhabit\b/i, label: "habit" },
      { re: /\bcomplete your plan\b/i, label: "complete your plan" },
      { re: /\bdue date\b/i, label: "due date" },
      { re: /\bnotification\b/i, label: "notification" },
      { re: /\bstreak\b/i, label: "streak" },
      { re: /\bkanban\b/i, label: "kanban" },
      { re: /\bdashboard\b/i, label: "dashboard" },
    ];

    const EXT = new Set([".tsx", ".ts"]);
    const SCAN_DIRS = ["app", "components"];

    const missing = requireOrDeferAll(REQUIRED_FILES, fail).filter(
      (rel) => !fs.existsSync(path.join(ROOT, rel)),
    );
    if (missing.length > 0) {
        for (const file of missing) fail(`missing file: ${file}`);
      }

    const typesFile = fs.readFileSync(path.join(ROOT, "packages/shared/types/open-loop.ts"), "utf8");
    for (const token of [
      "openLoopId",
      "sourceEntryId",
      "lastMentionedAt",
      "recurrenceCount",
      "firstSeenAt",
      "strongestAnchorPhrase",
      "emotionalShiftSummary",
      "connectedMoments",
      "closureNote",
      "softened",
    ]) {
      if (!typesFile.includes(token)) {
            process.exit(1);
      }
    }

    const linesFile = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/open-loops/open-loop-resurfacing-lines.ts"),
      "utf8",
    );
    if (!linesFile.includes("passesResurfacingGenericityGate")) {
        process.exit(1);
    }

    const copyFile = fs.readFileSync(path.join(ROOT, "packages/shared/lib/open-loops/open-loop-copy.ts"), "utf8");
    for (const token of [
      "Earlier moments connected to this",
      "What changed?",
      "Threads still open",
    ]) {
      if (!copyFile.includes(token)) {
            process.exit(1);
      }
    }

    const storage = fs.readFileSync(path.join(ROOT, "packages/shared/lib/open-loops/open-loop-storage.ts"), "utf8");
    for (const token of ["closeOpenLoop", "pickOpenLoopResurfacingLine", "recurrenceCount"]) {
      if (!storage.includes(token)) {
            process.exit(1);
      }
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

    const violations = [];
    for (const file of SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)))) {
      const rel = path.relative(ROOT, file);
      if (!rel.includes("open-loops") && !rel.includes("OpenLoop")) continue;

      const content = fs.readFileSync(file, "utf8");
      content.split("\n").forEach((line, index) => {
        const trimmed = line.trim();
        if (trimmed.startsWith("//") || trimmed.startsWith("*")) return;
        for (const { re, label } of USER_FACING_BANNED) {
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

async function checkOpenLoopsTests() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const {resetUnresolvedDetectionCache} = await import("../packages/shared/lib/open-loops/unresolved-cache.ts");
    const {detectUnresolvedThread,
      hasUnresolvedThreadLanguage,} = await import("../packages/shared/lib/open-loops/unresolved-signals.ts");
    const {resetOpenLoopActivationCache} = await import("../packages/shared/lib/open-loops/open-loop-activation.ts");
    const {detectEmotionalShift} = await import("../packages/shared/lib/open-loops/emotional-shift.ts");
    const {pickOpenLoopResurfacingLine} = await import("../packages/shared/lib/open-loops/open-loop-resurfacing-lines.ts");
    const {hasLongAbsenceReturn} = await import("../packages/shared/lib/open-loops/open-loop-silence.ts");
    const {auditOpenLoopActivation} = await import("../packages/shared/lib/open-loops/open-loop-activation-audit.ts");
    const {resolveOpenLoopActivation} = await import("../packages/shared/lib/open-loops/open-loop-activation.ts");

    resetUnresolvedDetectionCache();
    resetOpenLoopActivationCache();
    const HAUNTED_TRANSCRIPT =
      "I am haunted by the past, the present and the future. I'm scared.";

    assert.equal(hasUnresolvedThreadLanguage(HAUNTED_TRANSCRIPT), true);
    const hauntedSignal = detectUnresolvedThread(HAUNTED_TRANSCRIPT);
    assert.ok(hauntedSignal);
    assert.match(hauntedSignal.anchorPhrases.join(" "), /haunted|scared/i);
    assert.ok(hauntedSignal.matchedLabels.some((l) => /haunted|scared/i.test(l)));

    const hauntedEntry = {
      id: "entry-haunted-fixture",
      createdAt: "2026-05-01T12:00:00.000Z",
      transcript: HAUNTED_TRANSCRIPT,
      reflection: {
        mood: "anxious",
        emotionalIntensity: 6,
        recurringThemes: [],
        hiddenConcern: "",
        positiveSignal: "",
        recommendation: "",
      },
      durationSeconds: 42,
    };

    const hauntedAudit = auditOpenLoopActivation(hauntedEntry, {
      dismissed: false,
      hasLoop: false,
    });
    assert.equal(hauntedAudit.unresolvedDetected, true);
    assert.equal(hauntedAudit.showPrompt, true);
    assert.equal(hauntedAudit.activationSuppressedReason, null);

    const hauntedActivation = resolveOpenLoopActivation(hauntedEntry);
    assert.equal(hauntedActivation.showPrompt, true);
    assert.ok(hauntedActivation.signal);
    assert.equal(hasUnresolvedThreadLanguage("I need to call them back tomorrow."), true);
    assert.equal(
      hasUnresolvedThreadLanguage("Today was fine. Nothing unresolved."),
      false,
    );

    const signal = detectUnresolvedThread(
      "I keep avoiding the conversation. It sits there all week.",
    );
    assert.ok(signal);
    assert.match(signal.anchorPhrases[0], /avoiding/i);

    const waiting = detectUnresolvedThread("I'm waiting for them to reply before I decide.");
    assert.ok(waiting);
    assert.match(waiting.anchorPhrases[0], /waiting/i);
    assert.equal(waiting.concernLabel, "Waiting");

    const baseLoop = (overrides = {}) =>
      ({
        openLoopId: "loop-1",
        sourceEntryId: "entry-1",
        title: "Waiting",
        userNextStep: "Call when ready",
        status: "open",
        createdAt: "2026-01-01T10:00:00.000Z",
        updatedAt: "2026-02-01T10:00:00.000Z",
        lastMentionedAt: "2026-02-01T10:00:00.000Z",
        firstSeenAt: "2026-01-01T10:00:00.000Z",
        relatedEntryIds: ["entry-1", "entry-2"],
        anchorPhrases: ["I'm waiting for them", "still waiting"],
        concernLabel: "Waiting",
        recurrenceCount: 2,
        strongestAnchorPhrase: "I'm waiting for them",
        connectedMoments: [],
        mentionHistory: [
          "2026-01-01T10:00:00.000Z",
          "2026-02-15T10:00:00.000Z",
        ],
        ...overrides,
      });

    const quoteLine = pickOpenLoopResurfacingLine(baseLoop());
    assert.ok(quoteLine);
    assert.match(quoteLine, /From this reflection:|you kept this thread open/i);
    assert.match(quoteLine, /waiting for them/i);

    const gapLine = pickOpenLoopResurfacingLine(
      baseLoop({
        strongestAnchorPhrase: "still here",
        userNextStep: "ok",
        anchorPhrases: ["still here", "again"],
        concernLabel: "Other",
      }),
    );
    assert.ok(gapLine);
    assert.match(gapLine, /after \d+ days/i);

    const softenedLine = pickOpenLoopResurfacingLine(
      baseLoop({ status: "softened" }),
    );
    assert.ok(softenedLine);
    assert.match(softenedLine, /softened|kept this thread open/i);

    const softenedOnlyLine = pickOpenLoopResurfacingLine(
      baseLoop({
        status: "softened",
        strongestAnchorPhrase: "brief",
        userNextStep: "ok",
        anchorPhrases: ["brief"],
        concernLabel: "Other",
      }),
    );
    assert.equal(softenedOnlyLine, "You once marked this as softened.");

    const specificLine = pickOpenLoopResurfacingLine(
      baseLoop({
        strongestAnchorPhrase: "I keep avoiding the conversation with my manager",
        userNextStep: "Send the email before Friday",
      }),
    );
    assert.ok(specificLine);
    assert.match(specificLine, /avoiding|Send the email/i);

    const absenceLoop = baseLoop({
      mentionHistory: [
        "2026-01-01T10:00:00.000Z",
        "2026-01-20T10:00:00.000Z",
      ],
    });
    assert.equal(hasLongAbsenceReturn(absenceLoop), true);

    const shift = detectEmotionalShift(
      [
        {
          id: "a",
          createdAt: "2026-01-01T10:00:00.000Z",
          transcript: "I keep avoiding this call.",
          reflection: { mood: "anxious", emotionalIntensity: 7, recurringThemes: [], hiddenConcern: "", positiveSignal: "", recommendation: "" },
          durationSeconds: 30,
        },
        {
          id: "b",
          createdAt: "2026-01-20T10:00:00.000Z",
          transcript: "I came back to mention it again.",
          reflection: { mood: "anxious", emotionalIntensity: 7, recurringThemes: [], hiddenConcern: "", positiveSignal: "", recommendation: "" },
          durationSeconds: 30,
        },
      ],
      ["avoiding"],
    );
    assert.equal(shift.shift, "avoided_then_revisited");
    assert.equal(shift.confidence, "high");
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkOpenLoopsPerformance() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const {getCachedUnresolvedThread,
      resetUnresolvedDetectionCache,} = await import("../packages/shared/lib/open-loops/unresolved-cache.ts");
    const {getUnresolvedDetectionRunCount,
      resetOpenLoopPerformanceCounters,} = await import("../packages/shared/lib/open-loops/open-loop-performance.ts");
    const {resetOpenLoopActivationCache,
      resolveOpenLoopActivation,} = await import("../packages/shared/lib/open-loops/open-loop-activation.ts");
    const {resolveOpenLoopActivationSuppression} = await import("../packages/shared/lib/open-loops/open-loop-activation-audit.ts");

    const HAUNTED =
      "I am haunted by the past, the present and the future. I'm scared.";

    resetUnresolvedDetectionCache();
    resetOpenLoopActivationCache();
    resetOpenLoopPerformanceCounters();

    getCachedUnresolvedThread(HAUNTED);
    getCachedUnresolvedThread(HAUNTED);
    getCachedUnresolvedThread(HAUNTED);

    assert.ok(getUnresolvedDetectionRunCount() <= 2, `expected <=2 detection runs, got ${getUnresolvedDetectionRunCount()}`);

    const entry = {
      id: "perf-entry-1",
      createdAt: "2026-05-01T12:00:00.000Z",
      transcript: HAUNTED,
      reflection: {
        mood: "anxious",
        emotionalIntensity: 6,
        recurringThemes: [],
        hiddenConcern: "",
        positiveSignal: "",
        recommendation: "",
      },
      durationSeconds: 30,
    };

    const activation = resolveOpenLoopActivation(entry);
    assert.equal(activation.showPrompt, true);
    assert.equal(
      resolveOpenLoopActivationSuppression(entry, { dismissed: false, hasLoop: false }),
      null,
    );

    resolveOpenLoopActivation(entry);
    resolveOpenLoopActivation(entry);
    assert.ok(activation.showPrompt, "prompt allowed on hydration path");
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkOpenLoopRender() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const SCANNED = [
      "packages/shared/lib/open-loops/unresolved-signals.ts",
      "packages/shared/lib/open-loops/unresolved-detect-core.ts",
      "packages/shared/lib/open-loops/unresolved-cache.ts",
      "packages/shared/lib/open-loops/open-loop-continuity.ts",
      "packages/shared/lib/open-loops/open-loop-storage.ts",
      "apps/web/components/entry/OpenLoopNextStepPrompt.tsx",
      "apps/web/components/open-loops/OpenLoopEntryContinuity.tsx",
    ];

    const USE_MEMO_RE = /useMemo\s*\(/g;

    const FORBIDDEN_IN_RENDER_PATHS = [
      "localStorage.setItem",
      "sessionStorage.setItem",
      "refreshOpenLoopContinuity(",
      "refreshAllOpenLoopContinuity(",
      "maybeLinkReflectionAfterOpenLoopResurface(",
      "createOpenLoop(",
      "trackLocalEvent",
      "trackOpenLoop",
      "recordCallback",
      "recordLearningEvent",
    ];

    function stripUseEffect(source) {
      let result = "";
      let i = 0;
      while (i < source.length) {
        const idx = source.indexOf("useEffect", i);
        if (idx === -1) {
          result += source.slice(i);
          break;
        }
        result += source.slice(i, idx);
        i = idx + "useEffect".length;
        if (source[i] !== "(") {
          result += "useEffect";
          continue;
        }
        let depth = 0;
        let started = false;
        while (i < source.length) {
          const ch = source[i];
          if (ch === "(") {
            depth += 1;
            started = true;
          } else if (ch === ")") {
            depth -= 1;
            if (started && depth === 0) {
              i += 1;
              break;
            }
          }
          i += 1;
        }
      }
      return result;
    }

    function extractUseMemoCallbacks(source) {
      const blocks = [];
      USE_MEMO_RE.lastIndex = 0;
      let match;
      while ((match = USE_MEMO_RE.exec(source)) !== null) {
        let depth = 0;
        let j = match.index + match[0].length;
        let started = false;
        while (j < source.length) {
          const ch = source[j];
          if (ch === "(") {
            depth += 1;
            started = true;
          } else if (ch === ")") {
            if (!started) break;
            depth -= 1;
            if (depth === 0) {
              blocks.push(source.slice(match.index, j + 1));
              break;
            }
          }
          j += 1;
        }
      }
      return blocks;
    }

    function extractFunctionBodies(source, names) {
      const bodies = [];
      for (const name of names) {
        const re = new RegExp(`export function ${name}\\s*\\(`, "g");
        let match;
        while ((match = re.exec(source)) !== null) {
          const braceStart = source.indexOf("{", match.index);
          if (braceStart === -1) continue;
          let depth = 0;
          let end = braceStart;
          for (let i = braceStart; i < source.length; i += 1) {
            const ch = source[i];
            if (ch === "{") depth += 1;
            else if (ch === "}") {
              depth -= 1;
              if (depth === 0) {
                end = i + 1;
                break;
              }
            }
          }
          bodies.push({ name, body: source.slice(braceStart, end) });
        }
      }
      return bodies;
    }


    for (const rel of requireOrDeferAll(SCANNED, (m) => failures.push(m))) {
      const filePath = path.join(ROOT, rel);
      const source = fs.readFileSync(filePath, "utf8");
      const renderLike = stripUseEffect(source);

      for (const block of extractUseMemoCallbacks(renderLike)) {
        for (const token of FORBIDDEN_IN_RENDER_PATHS) {
          if (block.includes(token)) {
            failures.push(`${rel}: useMemo contains ${token}`);
          }
        }
      }

      if (rel.includes("unresolved-detect-core") || rel.includes("unresolved-cache")) {
        for (const { name, body } of extractFunctionBodies(source, [
          "detectUnresolvedThreadUncached",
          "getCachedUnresolvedThread",
        ])) {
          for (const token of FORBIDDEN_IN_RENDER_PATHS) {
            if (body.includes(token)) {
              failures.push(`${rel}: ${name} contains ${token}`);
            }
          }
        }
      }

      if (rel.endsWith("open-loop-storage.ts")) {
        const pickBody = extractFunctionBodies(source, ["pickEntryOpenLoopContinuityLine"])[0];
        if (pickBody?.body.includes("refreshOpenLoopContinuity(")) {
          failures.push(`${rel}: pickEntryOpenLoopContinuityLine must not refresh continuity synchronously`);
        }
        const getAllBody = extractFunctionBodies(source, ["getAllOpenLoops"])[0];
        if (getAllBody?.body.includes("refreshAllOpenLoopContinuity(")) {
          failures.push(`${rel}: getAllOpenLoops must not refresh all continuity on read`);
        }
      }
    }

    const entrySource = readOrDefer("apps/web/app/entry/[id]/page.tsx", (m) => failures.push(m));
    if (entrySource !== null && entrySource.includes("auditOpenLoopActivation(entry")) {
      failures.push("apps/web/app/entry/[id]/page.tsx: remove auditOpenLoopActivation from render effects");
    }


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
    const REQUIRED = [
      "packages/shared/lib/revisit/resurfacing-copy.ts",
      "packages/shared/lib/memory/resurfacing.ts",
      "packages/shared/lib/memory/revisitation.ts",
      "packages/shared/lib/revisit/revisit-quality.ts",
      "packages/shared/lib/refinement/callback-tuning.ts",
      "packages/shared/lib/refinement/reopen-payoff.ts",
    ];

    for (const rel of REQUIRED) {
      if (!fs.existsSync(path.join(ROOT, rel))) {
            process.exit(1);
      }
    }

    const resurfacingCopy = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/revisit/resurfacing-copy.ts"),
      "utf8",
    );
    const resurfacing = fs.readFileSync(path.join(ROOT, "packages/shared/lib/memory/resurfacing.ts"), "utf8");
    const revisitation = fs.readFileSync(path.join(ROOT, "packages/shared/lib/memory/revisitation.ts"), "utf8");
    const revisitQuality = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/revisit/revisit-quality.ts"),
      "utf8",
    );
    const callbackTuning = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/refinement/callback-tuning.ts"),
      "utf8",
    );
    const packageJson = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");

    const requiredCopy = [
      "You said something similar",
      "This came back in different words.",
      "The same concern showed up again, but softer.",
      "This used to sound heavier.",
      "You named this before, then left it alone.",
    ];

    for (const line of requiredCopy) {
      if (!resurfacingCopy.includes(line)) {
            process.exit(1);
      }
    }

    if (!resurfacingCopy.includes("isBlockedResurfacingCopy") || !resurfacingCopy.includes("ADVICE_RESURFACING_RE")) {
        process.exit(1);
    }

    if (!resurfacing.includes("pickResurfacingHeadline") || !resurfacing.includes("isBlockedResurfacingCopy")) {
        process.exit(1);
    }

    if (resurfacing.includes("You came back to the same place")) {
        process.exit(1);
    }

    if (!revisitation.includes("pickResurfacingHeadline")) {
        process.exit(1);
    }

    if (!revisitQuality.includes("isBlockedResurfacingCopy") || !revisitQuality.includes("scoreRepeatedPhrase")) {
        process.exit(1);
    }

    if (!fs.existsSync(path.join(ROOT, "packages/shared/lib/resurfacing/genericity-filter.ts"))) {
        process.exit(1);
    }

    if (!callbackTuning.includes("isBlockedResurfacingCopy")) {
        process.exit(1);
    }

    if (
      !callbackTuning.includes("passesResurfacingGenericityGate") ||
      !callbackTuning.includes("isGenericResurfacing")
    ) {
        process.exit(1);
    }

    if (!packageJson.includes("validate:resurfacing")) {
        process.exit(1);
    }
    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkSpecificity() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const SCAN = [
      "packages/shared/lib/memory/resurfacing.ts",
      "packages/shared/lib/memory/revisitation.ts",
      "packages/shared/lib/memory/familiarity-resurfacing.ts",
      "packages/shared/lib/revisit/resurfacing-confidence.ts",
      "packages/shared/lib/refinement/knows-me-moments.ts",
    ];

    const FORBIDDEN_LITERALS = [
      "thinking deeply",
      "going through a lot",
      "processing emotions",
      "been reflecting",
      "personal growth",
      "you seem stressed",
      "patterns are emerging",
      "you care deeply",
      "healing journey",
      "growth journey",
      "memory intelligence",
      "emotional architecture",
      "unlock your insights",
      "discover patterns",
    ];

    for (const rel of SCAN) {
      const filePath = path.join(ROOT, rel);
      if (!fs.existsSync(filePath)) continue;
      const content = fs.readFileSync(filePath, "utf8");
      for (const phrase of FORBIDDEN_LITERALS) {
        if (content.toLowerCase().includes(phrase.toLowerCase())) {
          failures.push(`${rel} contains forbidden phrase "${phrase}"`);
        }
      }
    }

    const copyPath = path.join(ROOT, "packages/shared/lib/revisit/resurfacing-copy.ts");
    const copy = fs.readFileSync(copyPath, "utf8");
    if (!copy.includes("isGenericResurfacing")) {
      failures.push("resurfacing-copy must use genericity filter (isGenericResurfacing)");
    }

    const packageJson = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
    for (const script of ["validate:genericity", "validate:homepage-clarity", "validate:resurfacing"]) {
      if (!packageJson.includes(script)) {
        failures.push(`package.json missing ${script}`);
      }
    }

    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkConfidence() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const REQUIRED = [
      "packages/shared/lib/revisit/resurfacing-confidence.ts",
      "packages/shared/types/resurfacing-confidence.ts",
      "packages/shared/lib/debug/resurfacing-confidence-review.ts",
      "apps/web/components/internal/ResurfacingConfidenceDebugPanel.tsx",
      "apps/web/app/internal/resurfacing-confidence/page.tsx",
      "packages/shared/lib/revisit/resurfacing-copy.ts",
      "packages/shared/lib/refinement/quiet-presentation.ts",
      "packages/shared/lib/refinement/revisit-experience.ts",
      "packages/shared/lib/revisit/revisit-quality.ts",
      "packages/shared/lib/refinement/callback-tuning.ts",
      "packages/shared/lib/retention/first-magic-moment.ts",
    ];

    requireOrDeferAll(REQUIRED, (m) => failures.push(m));

    const confidence = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/revisit/resurfacing-confidence.ts"),
      "utf8",
    );
    const copy = fs.readFileSync(path.join(ROOT, "packages/shared/lib/revisit/resurfacing-copy.ts"), "utf8");
    const memoryNote = fs.readFileSync(path.join(ROOT, "packages/shared/types/memory-note.ts"), "utf8");
    const memoryNoteComponent =
      readOrDefer("apps/web/components/patterns/MemoryNote.tsx", (m) => failures.push(m)) ?? "";
    const packageJson = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");

    for (const name of [
      "CONFIDENCE_SUPPRESS_MAX",
      "CONFIDENCE_PLAUSIBLE_MIN",
      "CONFIDENCE_STRONG_MIN",
      "CONFIDENCE_MAGIC_MIN",
    ]) {
      if (!confidence.includes(name)) {
        failures.push(`resurfacing-confidence missing threshold ${name}`);
      }
    }

    if (!confidence.includes("assessResurfacingConfidence") || !confidence.includes("shouldSuppressResurfacingConfidence")) {
      failures.push("resurfacing-confidence missing core scoring exports");
    }

    if (!confidence.includes("mood_only_match") || !confidence.includes("no_why_now")) {
      failures.push("resurfacing-confidence missing weak/generic suppress rules");
    }

    for (const line of [
      "You said something similar",
      "This concern came back in different words",
      "This concern showed up again after a quiet stretch.",
      "You mentioned",
      "Your tone changed around the same topic.",
      "This came back on the same kind of day.",
    ]) {
      if (!copy.includes(line)) {
        failures.push(`resurfacing-copy missing evidence copy: ${line}`);
      }
    }

    if (!copy.includes("pickResurfacingEvidenceReason") || !copy.includes("RESURFACING_WHY_NOW_COPY")) {
      failures.push("resurfacing-copy missing evidence reason picker");
    }

    if (!memoryNote.includes("evidenceReason")) {
      failures.push("MemoryNote type missing evidenceReason");
    }

    for (const pattern of [
      /totalConfidence/,
      /confidence score/i,
      /your score/i,
      /\b\d{1,3}% confidence\b/i,
    ]) {
      if (pattern.test(memoryNoteComponent)) {
        failures.push("user-facing numeric confidence in MemoryNote UI");
        break;
      }
    }

    if (!packageJson.includes("validate:resurfacing")) {
      failures.push("package.json must wire validate:resurfacing");
    }

    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkTiming() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const REQUIRED = [
      "packages/shared/lib/revisit/resurfacing-timing.ts",
      "packages/shared/types/resurfacing-timing.ts",
      "packages/shared/lib/debug/resurfacing-timing-review.ts",
      "apps/web/components/internal/ResurfacingTimingDebugPanel.tsx",
      "apps/web/app/internal/resurfacing-timing/page.tsx",
      "packages/shared/lib/revisit/resurfacing-confidence.ts",
      "packages/shared/lib/refinement/callback-tuning.ts",
      "packages/shared/lib/refinement/revisit-experience.ts",
      "packages/shared/lib/retention/first-magic-moment.ts",
    ];

    requireOrDeferAll(REQUIRED, (m) => failures.push(m));

    const timing = fs.readFileSync(
      path.join(ROOT, "packages/shared/lib/revisit/resurfacing-timing.ts"),
      "utf8",
    );
    const memoryNote =
      readOrDefer("apps/web/components/patterns/MemoryNote.tsx", (m) => failures.push(m)) ?? "";
    const packageJson = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");

    for (const name of [
      "TIMING_MIN_EMOTIONAL_DISTANCE_DAYS",
      "TIMING_SAME_DAY_STRONG_PHRASE_MIN",
      "TIMING_NOVELTY_COOLDOWN_HOURS",
      "TIMING_REPEATED_CALLBACK_COOLDOWN_DAYS",
      "TIMING_FRESHNESS_DECAY_DAYS",
      "TIMING_LONG_GAP_BOOST_DAYS",
      "TIMING_SILENCE_GAP_DAYS",
    ]) {
      if (!timing.includes(name)) {
        failures.push(`resurfacing-timing missing constant ${name}`);
      }
    }

    for (const name of [
      "assessResurfacingTiming",
      "shouldSuppressResurfacingTiming",
      "isResurfacingTimingEligible",
      "pickTimingEligibleNotes",
    ]) {
      if (!timing.includes(name)) {
        failures.push(`resurfacing-timing missing export ${name}`);
      }
    }

    for (const rule of [
      "same_day",
      "minimum_emotional_distance",
      "novelty_cooldown",
      "repeated_callback_cooldown",
      "already_processed",
      "freshness_decay",
    ]) {
      if (!timing.includes(rule)) {
        failures.push(`resurfacing-timing missing suppress rule ${rule}`);
      }
    }

    for (const pattern of [
      /timingScore/,
      /timing score/i,
      /timingClass/,
      /strong_timing/,
      /cooling_down/,
    ]) {
      if (pattern.test(memoryNote)) {
        failures.push("timing metadata exposed in MemoryNote UI");
        break;
      }
    }

    if (!packageJson.includes("validate:resurfacing")) {
      failures.push("package.json must wire validate:resurfacing");
    }

    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}

async function checkEvidence() {
  const failures = [];
  const fail = (msg) => failures.push(msg);
  try {
    const { runCanonicalPipelineForContinuity } = await import(
      "../packages/shared/lib/resurfacing/canonical-resurfacing-pipeline.ts"
    );
    const { buildResurfacingEvidence, hasResurfacingEvidenceAnchors } = await import(
      "../packages/shared/lib/resurfacing/resurfacing-evidence.ts"
    );

    const noEvidence = runCanonicalPipelineForContinuity({
      quote: "stressed",
      appearances: 1,
    });
    if (noEvidence.show) {
      failures.push("generic low-evidence quote must not show");
    }

    const withEvidence = runCanonicalPipelineForContinuity({
      quote: '"I keep saying I will call her back tomorrow — same line again"',
      appearances: 4,
      gapDays: 5,
      threadType: "repeated_phrase",
    });
    if (!withEvidence.show) {
      failures.push("quote-backed recurrence should pass gate");
    }
    const whyLine = withEvidence.whySurfacedLines?.[0] ?? "";
    if (!whyLine || whyLine.length < 12) {
      failures.push("why-surfaced line required when shown");
    }

    const evidence = buildResurfacingEvidence({
      quote: '"manager keeps moving the deadline"',
      appearances: 3,
      gapDays: 8,
    });
    if (!hasResurfacingEvidenceAnchors(evidence) && evidence.exactQuoteMatches.length === 0) {
      failures.push("evidence object must include anchors for quoted input");
    }

    const stale = runCanonicalPipelineForContinuity({
      quote: '"fine whatever"',
      appearances: 4,
      gapDays: 35,
    });
    if (stale.show) {
      failures.push("stale callback without reinforcement should suppress");
    }

    return failures;
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
    return failures;
  }
}