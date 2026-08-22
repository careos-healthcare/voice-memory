#!/usr/bin/env node
/**
 * Runs focused-beta final gate automated checks (Sections A–D),
 * updates release/focused_beta_status.json, and evaluates blockers.
 */
import fs from "node:fs";
import path from "node:path";
import {
  MANIFEST_PATH,
  NON_WAIVABLE_GATE_IDS,
  evaluateRelease,
  formatBlockerTable,
  loadManifest,
  writeGeneratedDocs,
} from "./focused-beta-core.mjs";
import {
  GATE_DEFINITIONS,
  runAutomatedCheck,
  readCurrentIdentity,
  summarizeOutput,
  writeEvidence,
  ensureMobileFlutterDeps,
} from "./focused-beta-gate-checks.mjs";

function isoNow() {
  return new Date().toISOString();
}

/** @param {object} manifest */
function syncGateDefinitions(manifest) {
  const byId = new Map(manifest.gates.map((g) => [g.id, g]));
  /** @type {object[]} */
  const merged = [];

  for (const def of GATE_DEFINITIONS) {
    const existing = byId.get(def.id);
    if (existing) {
      existing.title = def.title;
      existing.section = def.section;
      existing.automated = def.automated;
      existing.nonWaivable = NON_WAIVABLE_GATE_IDS.has(def.id);
      merged.push(existing);
    } else {
      merged.push({
        id: def.id,
        title: def.title,
        required: def.required,
        conditionalOn: def.conditionalOn,
        status: "not_run",
        recordedAt: null,
        commitSha: null,
        buildNumber: null,
        environment: "unrecorded",
        evidencePath: null,
        actor: def.actor,
        notes: "",
        waiver: null,
        section: def.section,
        automated: def.automated,
        nonWaivable: NON_WAIVABLE_GATE_IDS.has(def.id),
      });
    }
  }

  manifest.gates = merged;
}

/** @param {object} gate @param {"pass"|"fail"} status @param {object} identity @param {string} evidencePath @param {string} notes */
function applyAutomatedResult(gate, status, identity, evidencePath, notes) {
  gate.status = status;
  gate.recordedAt = isoNow();
  gate.commitSha = identity.commitSha;
  gate.buildNumber = identity.buildNumber;
  gate.environment = process.env.RELEASE_GATE_ENV ?? "local-gate-run";
  gate.evidencePath = evidencePath;
  gate.notes = notes;
  gate.waiver = null;
}

/** @param {object} manifest @param {{ dryRun?: boolean, skipBuilds?: boolean }} opts */
export function runFocusedBetaGate(manifest, opts = {}) {
  const identity = readCurrentIdentity();
  manifest.identity.semanticVersion = identity.semanticVersion;
  manifest.identity.buildNumber = identity.buildNumber;
  manifest.identity.commitSha = identity.commitSha;
  manifest.identity.createdAt = isoNow();

  syncGateDefinitions(manifest);

  // Resolve Flutter deps once; individual tests use --no-pub.
  ensureMobileFlutterDeps();

  /** @type {{ gateId: string, section: string, status: string, reason: string }[]} */
  const runResults = [];

  for (const def of GATE_DEFINITIONS) {
    const gate = manifest.gates.find((g) => g.id === def.id);
    if (!gate) continue;

    gate.section = def.section;
    gate.automated = def.automated;
    gate.nonWaivable = NON_WAIVABLE_GATE_IDS.has(def.id);

    if (def.conditionalOn) {
      const cap = manifest.capabilities[def.conditionalOn];
      if (!cap?.enabled) {
        if (gate.status !== "waived" && gate.status !== "not_run") {
          gate.status = "not_run";
          gate.notes = `conditional on ${def.conditionalOn}=false`;
        }
        continue;
      }
    }

    if (!def.automated) continue;

    if (opts.skipBuilds && def.section === "C" && def.id.startsWith("c_")) {
      runResults.push({
        gateId: def.id,
        section: def.section,
        status: "skipped",
        reason: "--skip-builds (status unchanged)",
      });
      continue;
    }

    const result = runAutomatedCheck(def.id);
    const evidencePath = writeEvidence(
      def.id,
      result.output || (result.ok ? "PASS\n" : "FAIL\n"),
    );

    if (result.ok) {
      applyAutomatedResult(
        gate,
        "pass",
        identity,
        evidencePath,
        summarizeOutput(result.output) || "exit 0",
      );
      runResults.push({
        gateId: def.id,
        section: def.section,
        status: "pass",
        reason: "automated check passed",
      });
    } else {
      applyAutomatedResult(
        gate,
        "fail",
        identity,
        evidencePath,
        summarizeOutput(result.output) || `exit ${result.exitCode ?? 1}`,
      );
      runResults.push({
        gateId: def.id,
        section: def.section,
        status: "fail",
        reason: summarizeOutput(result.output, 3) || "automated check failed",
      });
    }
  }

  if (!opts.dryRun) {
    fs.writeFileSync(MANIFEST_PATH, `${JSON.stringify(manifest, null, 2)}\n`);
    writeGeneratedDocs(manifest);
  }

  const evaluation = evaluateRelease(manifest, { headSha: identity.commitSha });
  return { manifest, identity, runResults, evaluation };
}

/** @param {ReturnType<typeof runFocusedBetaGate>} result */
export function printGateReport(result) {
  const { manifest, identity, runResults, evaluation } = result;
  console.log("Focused-beta final gate");
  console.log(
    `${manifest.identity.productName} ${identity.semanticVersion}+${identity.buildNumber} @ ${identity.commitSha.slice(0, 7)}`,
  );
  console.log("");

  const sections = ["A", "B", "C", "D", "E"];
  for (const section of sections) {
    const rows = runResults.filter((r) => r.section === section);
    if (rows.length === 0) continue;
    console.log(`Section ${section}`);
    for (const row of rows) {
      console.log(`  ${row.status.padEnd(7)} ${row.gateId} — ${row.reason}`);
    }
    console.log("");
  }

  console.log(formatBlockerTable(evaluation.blockers, evaluation.issues));

  if (evaluation.releaseAllowed) {
    console.log("RELEASE ALLOWED");
    return 0;
  }

  console.error(
    `RELEASE BLOCKED (${evaluation.blockers.length + evaluation.issues.length} issue(s))`,
  );
  return 1;
}

export function main(argv = process.argv.slice(2)) {
  const opts = {
    dryRun: argv.includes("--dry-run"),
    skipBuilds: argv.includes("--skip-builds"),
  };
  const manifest = loadManifest();
  const result = runFocusedBetaGate(manifest, opts);
  const code = printGateReport(result);
  if (argv.includes("--json")) {
    console.log(JSON.stringify(result.evaluation, null, 2));
  }
  return code;
}
