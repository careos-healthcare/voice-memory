#!/usr/bin/env node
/**
 * Shared focused-beta release manifest loader, schema validation, gate evaluation,
 * and deterministic Markdown generation.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import Ajv from "ajv";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const ROOT = path.resolve(__dirname, "../..");
export const MANIFEST_PATH = path.join(ROOT, "release/focused_beta_status.json");
export const SCHEMA_PATH = path.join(ROOT, "release/focused_beta_status.schema.json");
export const PUBSPEC_PATH = path.join(ROOT, "apps/mobile/pubspec.yaml");
export const REGISTRY_PATH = path.join(
  ROOT,
  "apps/mobile/lib/core/config/v1_capability_registry.dart",
);
export const ROUTER_PATH = path.join(ROOT, "apps/mobile/lib/router/app_router.dart");
export const SUMMARY_PATH = path.join(ROOT, "generated/release-summary.md");
export const CHECKLIST_PATH = path.join(ROOT, "generated/release-reviewer-checklist.md");

export const REQUIRED_GATE_IDS = [
  "a_production_graph_analyzer",
  "a_route_cta_integrity",
  "a_customer_language",
  "log_redaction",
  "sensitive_storage_scan",
  "a_disabled_capability_imports",
  "remote_consent_no_network_evidence",
  "b_capture_archive_behavior",
  "export_delete",
  "c_android_release_build",
  "c_ios_release_build",
  "c_web_release_build",
  "security_validators",
  "d_artifact_inspection",
  "e_manual_resilience_checklist",
  "voiceover_talkback_manual",
  "testflight_internal_smoke",
  "ios_android_build_signing",
  "sync_offline_conflict",
  "purchase_restore",
  "notifications_push",
  "native_extensions_widgets",
];

/** Gates that may never be waived — privacy, data loss, export, deletion, secret leak. */
export const NON_WAIVABLE_GATE_IDS = new Set([
  "remote_consent_no_network_evidence",
  "sensitive_storage_scan",
  "log_redaction",
  "export_delete",
  "a_route_cta_integrity",
  "a_disabled_capability_imports",
  "a_production_graph_analyzer",
  "d_artifact_inspection",
]);

/** Manual gates require signed evidence JSON fields when status is pass. */
export const MANUAL_EVIDENCE_REQUIRED_FIELDS = [
  "success",
  "build_number",
  "commit_sha",
  "tester",
  "device",
  "os",
  "timestamp",
  "attachment_path",
];

const ajv = new Ajv({ allErrors: true, strict: false });
ajv.addFormat("date-time", {
  type: "string",
  validate: (value) => typeof value === "string" && !Number.isNaN(Date.parse(value)),
});

/** @returns {string} */
export function readText(relOrAbs) {
  const p = path.isAbsolute(relOrAbs) ? relOrAbs : path.join(ROOT, relOrAbs);
  return fs.readFileSync(p, "utf8");
}

/** @returns {object} */
export function loadManifest(manifestPath = MANIFEST_PATH) {
  return JSON.parse(readText(manifestPath));
}

/** @returns {{ valid: boolean, errors: string[] }} */
export function validateManifestSchema(manifest, schemaPath = SCHEMA_PATH) {
  const schema = JSON.parse(readText(schemaPath));
  const validate = ajv.compile(schema);
  const valid = validate(manifest);
  if (valid) return { valid: true, errors: [] };
  const errors = (validate.errors ?? []).map(
    (e) => `${e.instancePath || "/"} ${e.message ?? "invalid"}`.trim(),
  );
  return { valid: false, errors };
}

/** @returns {{ semanticVersion: string, buildNumber: number, raw: string }} */
export function readPubspecIdentity(pubspecPath = PUBSPEC_PATH) {
  const text = readText(pubspecPath);
  const m = text.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$/m);
  if (!m) throw new Error(`Could not parse version from ${pubspecPath}`);
  return {
    semanticVersion: m[1],
    buildNumber: Number(m[2]),
    raw: `${m[1]}+${m[2]}`,
  };
}

/** @returns {string|null} */
export function readGitHead(full = true) {
  const gitHead = path.join(ROOT, ".git/HEAD");
  if (!fs.existsSync(gitHead)) return null;
  let ref = readText(gitHead).trim();
  if (ref.startsWith("ref: ")) {
    const refPath = path.join(ROOT, ".git", ref.slice(5).trim());
    if (!fs.existsSync(refPath)) return null;
    ref = readText(refPath).trim();
  }
  return full ? ref : ref.slice(0, 7);
}

/** @returns {Record<string, boolean|null>} */
export function readRegistryCapabilities(registryPath = REGISTRY_PATH) {
  const text = readText(registryPath);
  /** @param {string} name */
  const parseConst = (name) => {
    const m = text.match(new RegExp(`static const bool ${name} = (true|false);`));
    return m ? m[1] === "true" : null;
  };
  return {
    storeBilling: parseConst("storeBilling"),
    notifications: parseConst("notifications"),
    nativeExtensions: parseConst("nativeExtensions"),
  };
}

/** @returns {boolean} */
export function readSyncEnabled(routerPath = ROUTER_PATH) {
  return readText(routerPath).includes("OfflineSyncVerificationScreen");
}

/**
 * @param {object} manifest
 * @returns {string[]}
 */
export function validateManifestCapabilitiesAgainstRegistry(manifest) {
  const issues = [];
  const registry = readRegistryCapabilities();
  const syncEnabled = readSyncEnabled();
  const caps = manifest.capabilities;

  if (caps.storeBilling.enabled !== registry.storeBilling) {
    issues.push(
      `capabilities.storeBilling.enabled (${caps.storeBilling.enabled}) != V1CapabilityRegistry.storeBilling (${registry.storeBilling})`,
    );
  }
  if (caps.notifications.enabled !== registry.notifications) {
    issues.push(
      `capabilities.notifications.enabled (${caps.notifications.enabled}) != V1CapabilityRegistry.notifications (${registry.notifications})`,
    );
  }
  if (caps.nativeExtensions.enabled !== registry.nativeExtensions) {
    issues.push(
      `capabilities.nativeExtensions.enabled (${caps.nativeExtensions.enabled}) != V1CapabilityRegistry.nativeExtensions (${registry.nativeExtensions})`,
    );
  }
  if (caps.sync.enabled !== syncEnabled) {
    issues.push(
      `capabilities.sync.enabled (${caps.sync.enabled}) != OfflineSyncVerificationScreen present in router (${syncEnabled})`,
    );
  }
  return issues;
}

/** @param {string|null|undefined} sha */
function normalizeSha(sha) {
  if (!sha) return null;
  return sha.toLowerCase();
}

/** @param {string|null|undefined} a @param {string|null|undefined} b */
export function shaMatches(a, b) {
  const na = normalizeSha(a);
  const nb = normalizeSha(b);
  if (!na || !nb) return false;
  const min = Math.min(na.length, nb.length);
  return na.slice(0, min) === nb.slice(0, min);
}

/** @param {string|null|undefined} iso */
function parseIso(iso) {
  if (!iso) return null;
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** @param {string} rel */
function evidenceExists(rel) {
  if (!rel) return false;
  return fs.existsSync(path.join(ROOT, rel));
}

/**
 * @typedef {object} GateBlocker
 * @property {string} gateId
 * @property {string} title
 * @property {string} reason
 * @property {string} status
 */

/**
 * @param {object} gate
 * @param {object} identity
 * @param {object} capabilities
 * @param {object} [opts]
 * @returns {GateBlocker[]}
 */
export function evaluateGate(gate, identity, capabilities, opts = {}) {
  const blockers = [];
  const now = opts.now ? new Date(opts.now) : new Date();
  const headSha = opts.headSha ?? readGitHead(true);

  const capabilityEnabled =
    gate.conditionalOn == null ? true : Boolean(capabilities[gate.conditionalOn]?.enabled);

  if (gate.conditionalOn && !capabilityEnabled) {
    if (gate.status === "waived") {
      if (gate.waiver) {
        const expires = parseIso(gate.waiver.expiresAt);
        if (expires && expires.getTime() < now.getTime()) {
          blockers.push({
            gateId: gate.id,
            title: gate.title,
            reason: `waiver expired at ${gate.waiver.expiresAt}`,
            status: gate.status,
          });
        }
      }
      return blockers;
    }
    if (gate.status === "not_run") return blockers;
    blockers.push({
      gateId: gate.id,
      title: gate.title,
      reason: `conditional gate (${gate.conditionalOn} disabled) must be waived or not_run, got ${gate.status}`,
      status: gate.status,
    });
    return blockers;
  }

  if (!gate.required) return blockers;

  if (gate.status === "fail") {
    blockers.push({
      gateId: gate.id,
      title: gate.title,
      reason: gate.notes || "gate status is fail",
      status: gate.status,
    });
    return blockers;
  }

  if (gate.status === "not_run") {
    blockers.push({
      gateId: gate.id,
      title: gate.title,
      reason: "required gate has not_run status",
      status: gate.status,
    });
    return blockers;
  }

  if (gate.status === "waived") {
    if (NON_WAIVABLE_GATE_IDS.has(gate.id)) {
      blockers.push({
        gateId: gate.id,
        title: gate.title,
        reason: "non-waivable gate cannot be waived",
        status: gate.status,
      });
      return blockers;
    }
    if (!gate.waiver) {
      blockers.push({
        gateId: gate.id,
        title: gate.title,
        reason: "waived gate missing waiver object",
        status: gate.status,
      });
      return blockers;
    }
    const expires = parseIso(gate.waiver.expiresAt);
    if (!expires) {
      blockers.push({
        gateId: gate.id,
        title: gate.title,
        reason: "waiver expiresAt is invalid",
        status: gate.status,
      });
      return blockers;
    }
    if (expires.getTime() < now.getTime()) {
      blockers.push({
        gateId: gate.id,
        title: gate.title,
        reason: `waiver expired at ${gate.waiver.expiresAt}`,
        status: gate.status,
      });
      return blockers;
    }
    const maxDays = identity.expirationPolicy.waiverMaxDays;
    const approved = parseIso(gate.waiver.approvedAt);
    if (approved) {
      const ageDays = (now.getTime() - approved.getTime()) / (86400 * 1000);
      if (ageDays > maxDays) {
        blockers.push({
          gateId: gate.id,
          title: gate.title,
          reason: `waiver older than waiverMaxDays (${maxDays})`,
          status: gate.status,
        });
      }
    }
    return blockers;
  }

  if (gate.status === "pass") {
    if (!gate.evidencePath) {
      blockers.push({
        gateId: gate.id,
        title: gate.title,
        reason: "pass gate missing evidencePath",
        status: gate.status,
      });
      return blockers;
    }
    if (!evidenceExists(gate.evidencePath)) {
      blockers.push({
        gateId: gate.id,
        title: gate.title,
        reason: `missing evidence file: ${gate.evidencePath}`,
        status: gate.status,
      });
      return blockers;
    }

    if (gate.buildNumber != null && gate.buildNumber !== identity.buildNumber) {
      blockers.push({
        gateId: gate.id,
        title: gate.title,
        reason: `build mismatch: gate ${gate.buildNumber} != identity ${identity.buildNumber}`,
        status: gate.status,
      });
    }

    if (gate.commitSha && headSha && !shaMatches(gate.commitSha, identity.commitSha)) {
      blockers.push({
        gateId: gate.id,
        title: gate.title,
        reason: `commit mismatch: gate ${gate.commitSha.slice(0, 7)} != identity ${identity.commitSha.slice(0, 7)}`,
        status: gate.status,
      });
    } else if (gate.commitSha && headSha && !shaMatches(gate.commitSha, headSha)) {
      blockers.push({
        gateId: gate.id,
        title: gate.title,
        reason: `commit mismatch: gate ${gate.commitSha.slice(0, 7)} != HEAD ${headSha.slice(0, 7)}`,
        status: gate.status,
      });
    }

    const recorded = parseIso(gate.recordedAt);
    const staleDays = identity.expirationPolicy.gateEvidenceStaleAfterDays;
    if (recorded) {
      const ageDays = (now.getTime() - recorded.getTime()) / (86400 * 1000);
      if (ageDays > staleDays) {
        blockers.push({
          gateId: gate.id,
          title: gate.title,
          reason: `evidence stale: recorded ${gate.recordedAt} (> ${staleDays} days)`,
          status: gate.status,
        });
      }
    } else {
      blockers.push({
        gateId: gate.id,
        title: gate.title,
        reason: "pass gate missing recordedAt timestamp",
        status: gate.status,
      });
    }

    if (gate.evidencePath.endsWith(".json")) {
      try {
        const payload = JSON.parse(readText(gate.evidencePath));
        if (payload.success === false) {
          blockers.push({
            gateId: gate.id,
            title: gate.title,
            reason: `${gate.evidencePath} reports success:false`,
            status: gate.status,
          });
        }
        if (!payload.timestamp && !payload.recordedAt) {
          blockers.push({
            gateId: gate.id,
            title: gate.title,
            reason: `${gate.evidencePath} missing timestamp/recordedAt`,
            status: gate.status,
          });
        }
        if (gate.actor?.type === "manual" || gate.section === "E") {
          for (const field of MANUAL_EVIDENCE_REQUIRED_FIELDS) {
            if (payload[field] == null || payload[field] === "") {
              blockers.push({
                gateId: gate.id,
                title: gate.title,
                reason: `manual evidence missing required field: ${field}`,
                status: gate.status,
              });
            }
          }
          if (payload.attachment_path && !evidenceExists(payload.attachment_path)) {
            blockers.push({
              gateId: gate.id,
              title: gate.title,
              reason: `manual attachment missing: ${payload.attachment_path}`,
              status: gate.status,
            });
          }
        }
        if (payload.build_number != null) {
          const evidenceBuild = Number(payload.build_number);
          if (!Number.isNaN(evidenceBuild) && evidenceBuild !== identity.buildNumber) {
            blockers.push({
              gateId: gate.id,
              title: gate.title,
              reason: `evidence build_number ${evidenceBuild} != identity ${identity.buildNumber}`,
              status: gate.status,
            });
          }
        }
        if (payload.commit_sha && identity.commitSha) {
          if (!shaMatches(payload.commit_sha, identity.commitSha)) {
            blockers.push({
              gateId: gate.id,
              title: gate.title,
              reason: `evidence commit_sha ${String(payload.commit_sha).slice(0, 7)} != identity ${identity.commitSha.slice(0, 7)}`,
              status: gate.status,
            });
          }
        }
      } catch (e) {
        blockers.push({
          gateId: gate.id,
          title: gate.title,
          reason: `invalid JSON evidence: ${gate.evidencePath} (${e.message})`,
          status: gate.status,
        });
      }
    }
  }

  return blockers;
}

/**
 * @param {object} manifest
 * @param {object} [opts]
 */
export function evaluateRelease(manifest, opts = {}) {
  const issues = [];
  const schema = validateManifestSchema(manifest, opts.schemaPath ?? SCHEMA_PATH);
  if (!schema.valid) {
    for (const e of schema.errors) issues.push({ kind: "schema", message: e });
  }

  const pubspec = readPubspecIdentity(opts.pubspecPath ?? PUBSPEC_PATH);
  const identity = manifest.identity;
  if (identity.semanticVersion !== pubspec.semanticVersion) {
    issues.push({
      kind: "identity",
      message: `semanticVersion ${identity.semanticVersion} != pubspec ${pubspec.semanticVersion}`,
    });
  }
  if (identity.buildNumber !== pubspec.buildNumber) {
    issues.push({
      kind: "identity",
      message: `buildNumber ${identity.buildNumber} != pubspec ${pubspec.buildNumber}`,
    });
  }

  const headSha = opts.headSha ?? readGitHead(true);
  if (headSha && !shaMatches(identity.commitSha, headSha)) {
    issues.push({
      kind: "identity",
      message: `identity.commitSha ${identity.commitSha.slice(0, 7)} != HEAD ${headSha.slice(0, 7)}`,
    });
  }

  const capIssues = validateManifestCapabilitiesAgainstRegistry(manifest);
  for (const m of capIssues) issues.push({ kind: "capability", message: m });

  const gateIds = manifest.gates.map((g) => g.id);
  for (const id of REQUIRED_GATE_IDS) {
    if (!gateIds.includes(id)) {
      issues.push({ kind: "gate", message: `missing required gate id: ${id}` });
    }
  }

  /** @type {GateBlocker[]} */
  const blockers = [];
  for (const gate of manifest.gates) {
    blockers.push(...evaluateGate(gate, identity, manifest.capabilities, opts));
  }

  const created = parseIso(identity.createdAt);
  const now = opts.now ? new Date(opts.now) : new Date();
  if (created) {
    const ageDays = (now.getTime() - created.getTime()) / (86400 * 1000);
    if (ageDays > identity.expirationPolicy.manifestStaleAfterDays) {
      issues.push({
        kind: "identity",
        message: `manifest createdAt stale (> ${identity.expirationPolicy.manifestStaleAfterDays} days)`,
      });
    }
  }

  const releaseAllowed = schema.valid && issues.length === 0 && blockers.length === 0;
  return { releaseAllowed, issues, blockers, pubspec, headSha };
}

/** @param {object[]} blockers @param {object[]} issues */
export function formatBlockerTable(blockers, issues = []) {
  const lines = [];
  lines.push("");
  lines.push("| Gate | Status | Blocker |");
  lines.push("| --- | --- | --- |");
  for (const b of blockers) {
    lines.push(`| ${b.gateId} | ${b.status} | ${b.reason.replace(/\|/g, "\\|")} |`);
  }
  for (const i of issues) {
    lines.push(`| _${i.kind}_ | — | ${i.message.replace(/\|/g, "\\|")} |`);
  }
  if (blockers.length === 0 && issues.length === 0) {
    lines.push("| — | pass | all required gates satisfied |");
  }
  lines.push("");
  return lines.join("\n");
}

/** @param {object} manifest */
export function generateReleaseSummary(manifest) {
  const { identity, capabilities, gates } = manifest;
  const evaluation = evaluateRelease(manifest);
  const lines = [];
  lines.push("# ArchiveMe focused-beta release summary");
  lines.push("");
  lines.push("_Generated from `release/focused_beta_status.json`. Do not edit by hand._");
  lines.push("");
  lines.push("## Release identity");
  lines.push("");
  lines.push("| Field | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Product | ${identity.productName} |`);
  lines.push(`| Version | ${identity.semanticVersion}+${identity.buildNumber} |`);
  lines.push(`| Commit | \`${identity.commitSha.slice(0, 12)}\` |`);
  lines.push(`| Environment | ${identity.buildEnvironment} |`);
  lines.push(`| Created | ${identity.createdAt} |`);
  lines.push(`| Channel | ${identity.distributionChannel} |`);
  lines.push(`| Manifest stale after | ${identity.expirationPolicy.manifestStaleAfterDays} days |`);
  lines.push("");
  lines.push("## Capability registry snapshot");
  lines.push("");
  lines.push("| Capability | Enabled | Source |");
  lines.push("| --- | --- | --- |");
  for (const [key, cap] of Object.entries(capabilities)) {
    const live =
      key === "storeBilling" && "livePurchases" in cap
        ? ` (livePurchases=${cap.livePurchases})`
        : "";
    lines.push(`| ${key} | ${cap.enabled}${live} | ${cap.registrySource} |`);
  }
  lines.push("");
  lines.push("## Gate results");
  lines.push("");
  lines.push("| Gate | Required | Status | Evidence | Actor |");
  lines.push("| --- | --- | --- | --- | --- |");
  for (const gate of gates) {
    const req =
      gate.conditionalOn && !capabilities[gate.conditionalOn]?.enabled
        ? "conditional (skipped)"
        : gate.required
          ? "yes"
          : "no";
    const evidence = gate.evidencePath ?? "—";
    lines.push(
      `| ${gate.id} | ${req} | ${gate.status} | ${evidence} | ${gate.actor.name} |`,
    );
  }
  lines.push("");
  lines.push("## Release verdict");
  lines.push("");
  if (evaluation.releaseAllowed) {
    lines.push("**RELEASE ALLOWED** — all required gates pass for the current identity.");
  } else {
    lines.push("**RELEASE BLOCKED** — resolve blockers before packaging.");
    lines.push(formatBlockerTable(evaluation.blockers, evaluation.issues));
  }
  lines.push("");
  lines.push(`Blocking gates: ${evaluation.blockers.length + evaluation.issues.length}`);
  lines.push("");
  return lines.join("\n");
}

/** @param {object} manifest */
export function generateReviewerChecklist(manifest) {
  const evaluation = evaluateRelease(manifest);
  const lines = [];
  lines.push("# ArchiveMe focused-beta reviewer checklist");
  lines.push("");
  lines.push("_Generated from `release/focused_beta_status.json`. Do not edit by hand._");
  lines.push("");
  lines.push(`Version **${manifest.identity.semanticVersion}+${manifest.identity.buildNumber}** · commit \`${manifest.identity.commitSha.slice(0, 12)}\``);
  lines.push("");
  if (!evaluation.releaseAllowed) {
    lines.push("> **Release is blocked.** Complete machine gates before reviewer sign-off.");
    lines.push("");
  }
  lines.push("## Pre-submission gates");
  lines.push("");
  for (const gate of manifest.gates) {
    const cap = gate.conditionalOn;
    if (cap && !manifest.capabilities[cap]?.enabled) continue;
    const box = gate.status === "pass" || gate.status === "waived" ? "[x]" : "[ ]";
    lines.push(`${box} **${gate.title}** (\`${gate.id}\`) — ${gate.status}`);
    if (gate.evidencePath) lines.push(`  - Evidence: \`${gate.evidencePath}\``);
    if (gate.notes) lines.push(`  - Note: ${gate.notes}`);
    if (gate.waiver) {
      lines.push(
        `  - Waiver: ${gate.waiver.owner} — ${gate.waiver.reason} (expires ${gate.waiver.expiresAt})`,
      );
    }
  }
  lines.push("");
  lines.push("## Reviewer demo path (when release allowed)");
  lines.push("");
  lines.push("1. Fresh install → Record (`/record`) — typed moment without microphone.");
  lines.push("2. Voice moment after mic permission.");
  lines.push("3. Archive Home (`/archive-belief`).");
  lines.push("4. Sample Archive (`/sample-archive`) — example data only.");
  lines.push("5. Settings → Help & reviewer guide, Support, Privacy, Terms.");
  if (manifest.capabilities.storeBilling.enabled) {
    lines.push("6. Pro preview (`/pro-preview`) — no live purchase claim.");
    lines.push("7. Restore purchases — honest unavailable copy until billing ready.");
  } else {
    lines.push("6. Confirm no subscription, restore, or upgrade prompts appear.");
  }
  lines.push("");
  return lines.join("\n");
}

/** @param {object} manifest */
export function writeGeneratedDocs(manifest) {
  fs.mkdirSync(path.join(ROOT, "generated"), { recursive: true });
  fs.writeFileSync(SUMMARY_PATH, generateReleaseSummary(manifest));
  fs.writeFileSync(CHECKLIST_PATH, generateReviewerChecklist(manifest));
}

export function mainStatus(argv = process.argv.slice(2)) {
  const manifest = loadManifest();
  writeGeneratedDocs(manifest);
  const result = evaluateRelease(manifest);
  console.log(generateReleaseSummary(manifest));
  if (argv.includes("--json")) {
    console.log(JSON.stringify(result, null, 2));
  }
  return result;
}

export function mainVerify(argv = process.argv.slice(2)) {
  const manifest = loadManifest();
  writeGeneratedDocs(manifest);
  const result = evaluateRelease(manifest);
  const table = formatBlockerTable(result.blockers, result.issues);
  console.log("Focused-beta release verification");
  console.log(
    `${manifest.identity.productName} ${manifest.identity.semanticVersion}+${manifest.identity.buildNumber} @ ${manifest.identity.commitSha.slice(0, 7)}`,
  );
  console.log(table);
  if (result.releaseAllowed) {
    console.log("RELEASE ALLOWED");
    return 0;
  }
  console.error(`RELEASE BLOCKED (${result.blockers.length + result.issues.length} issue(s))`);
  if (argv.includes("--json")) {
    console.error(JSON.stringify(result, null, 2));
  }
  return 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  // module executed directly — no-op unless wired
}
