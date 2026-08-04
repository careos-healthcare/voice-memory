import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const currentDir = path.join(root, "docs/current");
const historyDir = path.join(root, "docs/history");

const HISTORY_BANNER =
  "> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.";

const ALLOWED_CURRENT_DOCUMENTS = [
  "ACCESSIBILITY_DEVICE_VERIFICATION.md",
  "ARCHITECTURE.md",
  "DATA_FLOW_AND_PRIVACY.md",
  "MIGRATIONS.md",
  "MONETIZATION_CONTRACT.md",
  // Carries the measured latency budgets a release is judged against, so it is
  // a release-decision document rather than a procedure or a historical note.
  "PERFORMANCE_REPORT.md",
  "PRODUCT_CONTRACT.md",
  "RELEASE_CHECKLIST.md",
  "STORE_IDENTITY_CHECKLIST.md",
];

/**
 * A forbidden claim is tolerated only when the claim's own sentence refutes it,
 * or when it is a list item or table row under a heading or lead-in that
 * refutes it. Refutation is deliberately rule-specific: a bare "no" or "not"
 * somewhere in the sentence must not launder an unrelated false claim, so each
 * rule declares the denial that actually neutralises it.
 */
const ABSENCE_OF_SURFACE =
  /\b(?:prohibited|forbidden|removed|excluded|absent|residual|obsolete|historical|superseded|deprecated|no longer (?:exists?|shipped|available|reachable)|not in this product|none of (?:them|these)|expose no|exposes no|makes no call|never shipped|not present|not shipped|not built|not reachable|not part of)\b|STILL_REACHABLE_ON_CUSTOM_SERVER|MIGRATION_ONLY/i;

/**
 * A non-canonical identifier may appear only where the sentence says so — as a
 * legacy, experimental or superseded value — never as a plain assertion.
 */
const IDENTIFIER_DISCLAIMER =
  /\b(?:legacy|experimental|superseded|historical|obsolete|deprecated|not canonical|non[\s-]canonical|must not|never|drift|placeholder|unused|do not use|previous|old)\b/i;

interface DriftRule {
  readonly id: string;
  readonly claim: RegExp;
  /** The only wording that may legitimately neutralise this claim. */
  readonly refuted: RegExp;
  readonly why: string;
}

const FORBIDDEN_CLAIMS: readonly DriftRule[] = [
  {
    id: "plaintext-preferences",
    claim:
      /plaintext\s+(?:app\s+)?prefe(?:rences|rs)|prefe(?:rences|rs)\s+(?:are|is)\s+(?:stored\s+)?(?:in\s+)?plaintext|unencrypted\s+prefe(?:rences|rs)|(?:^|[^A-Za-z])SharedPreferences/i,
    refuted: /\b(?:legacy|migrated|migrates|never|no longer|not)\b/i,
    why:
      "Preferences and keys are held in platform secure storage. " +
      "apps/voicememory_mobile/lib/storage/secure_storage.dart and " +
      "apps/voicememory_mobile/lib/storage/private_data_encryption_key_store.dart",
  },
  {
    id: "end-to-end-encryption",
    claim: /end[\s-]to[\s-]end\s+encrypt(?:ed|ion)?|\bE2EE\b/i,
    refuted:
      /\bnot\s+end[\s-]to[\s-]end|\bnot\s+E2EE\b|would overstate|must not be (?:called|described)/i,
    why:
      "The active sync path is client-side AES-GCM with a device-held key and no " +
      "key escrow or recovery exchange (saved_moment_sync_key_store.dart), which is " +
      "not end-to-end encryption",
  },
  {
    id: "local-only-processing",
    claim:
      /local[\s-]only|processing\s+is\s+local|process(?:ed|ing|es)?\s+(?:is\s+|are\s+)?(?:entirely\s+|fully\s+|wholly\s+|only\s+|all\s+)?on[\s-]device|on[\s-]device\s+(?:only|processing)|runs?\s+(?:entirely\s+|fully\s+)?(?:on|offline)[\s-]?device|stays?\s+on\s+(?:this|your)\s+device|(?:audio|recording|recordings|transcript|transcripts|words)\s+(?:will\s+)?never\s+leaves?\s+(?:your|the|this)\s+device|no\s+audio\s+(?:is\s+)?(?:ever\s+)?(?:sent|uploaded)|no\s+network\s+calls?/i,
    refuted:
      /\bnot\s+local[\s-]only|must never be described|no document\s+may|\bnot\s+on[\s-]device\b/i,
    why:
      "Transcription posts to /api/transcribe (whisper-1) and interpretation posts " +
      "to /api/analyze (gpt-4o-mini) from voice_capture_api_client.dart",
  },
  {
    id: "obsolete-onboarding",
    claim:
      /Over time your archive forms beliefs|Those beliefs strengthen, weaken, or disappear|Record your first reflection|Every reflection becomes evidence|Your archive keeps track of what keeps repeating|Speak for about a minute|onboarding carousel|paged onboarding|onboarding\s+PageView|ARCHIVE_ONBOARDING_SCREEN|(?:two|three|four|five|six|seven|eight|nine|ten|\d+)[\s-](?:screens?|pages?|steps?|slides?|stage?s)[^.\n]{0,60}onboarding|onboarding[^.\n]{0,60}(?:two|three|four|five|six|seven|eight|nine|ten|\d+)[\s-](?:screens?|pages?|steps?|slides?|stages?)|onboarding\s+(?:tour|walkthrough|carousel)|multi[\s-]step\s+onboarding/i,
    refuted:
      /no longer exists?|single promise screen|pageCount = 1|is drift\b|obsolete|superseded|historical/i,
    why:
      "Onboarding is a single promise screen. " +
      "apps/voicememory_mobile/lib/onboarding/onboarding_pages.dart declares pageCount = 1",
  },
  {
    id: "removed-surface-life-simulation",
    claim: /life[\s-]simulat|life simulator/i,
    refuted: ABSENCE_OF_SURFACE,
    why: "Life simulation is prohibited in archive_me_v1_contract.json",
  },
  {
    id: "removed-surface-horizon-simulation",
    claim: /horizon[\s-]simulat|horizon lab/i,
    refuted: ABSENCE_OF_SURFACE,
    why: "Horizon simulation is prohibited in archive_me_v1_contract.json",
  },
  {
    id: "removed-surface-life-story-replay",
    claim: /life[\s-]story[\s-]replay/i,
    refuted: ABSENCE_OF_SURFACE,
    why: "Life-story replay is a removed backend route",
  },
  {
    id: "removed-surface-generic-analyst",
    claim: /\banalyst\b|action[\s-]plan generator|search[\s-]translator/i,
    refuted: ABSENCE_OF_SURFACE,
    why: "The generic analyst surfaces are removed backend routes",
  },
  {
    id: "removed-surface-archive-synthesis",
    claim:
      /archive[\s-]synthesis|archive synthesis|cluster[\s-]synthesis|weekly[\s-]intelligence[\s-]synthesis/i,
    refuted: ABSENCE_OF_SURFACE,
    why: "Broad archive synthesis is a removed backend route",
  },
  {
    id: "removed-surface-dashboard-synthesis",
    claim: /dashboard[\s-]synthesis/i,
    refuted: ABSENCE_OF_SURFACE,
    why: "Dashboard synthesis is a removed backend route",
  },
  {
    id: "removed-surface-document-ingestion",
    claim: /document[\s-]ingestion|\bOCR\b/i,
    refuted: ABSENCE_OF_SURFACE,
    why: "Document ingestion is prohibited in archive_me_v1_contract.json",
  },
  {
    id: "removed-surface-graph",
    claim: /memory[\s-]graph|graph[\s-]sync|graph system|graph database|pattern[\s-]map/i,
    refuted: ABSENCE_OF_SURFACE,
    why: "Graph systems are prohibited in archive_me_v1_contract.json",
  },
  {
    id: "removed-surface-relationship-synthesis",
    claim: /relationship[\s-]synthesis/i,
    refuted: ABSENCE_OF_SURFACE,
    why: "Relationship synthesis is a removed backend route",
  },
  {
    id: "removed-surface-vision-extraction",
    claim: /vision[\s-]extraction/i,
    refuted: ABSENCE_OF_SURFACE,
    why: "Vision extraction is a removed backend route",
  },
  {
    id: "removed-surface-live-audio",
    claim: /live[\s-]audio|live[\s-]voice|voice[\s-]session|live AI (?:audio )?conversation/i,
    refuted: ABSENCE_OF_SURFACE,
    why: "Live AI audio conversation is prohibited in archive_me_v1_contract.json",
  },
  {
    id: "unearned-device-or-store-pass",
    claim:
      /verified on (?:a |the )?(?:real |physical )?device|device[\s-]verified|store[\s-]verified|verified in (?:the )?app store|verified in (?:the )?play console|tested on (?:a |the )?device|passed on (?:a |the )?device|purchase verified|restore verified|confirmed on (?:a |the )?device|store (?:review )?(?:passed|approved)/i,
    refuted:
      /BLOCKED_EXTERNAL|not device proof|cannot be claimed|must not be claimed|no (?:physical )?device was|unverified|no such claim/i,
    why:
      "No physical device or store dashboard was available. Every such gate is " +
      "BLOCKED_EXTERNAL and a written script is not device proof",
  },
  {
    id: "confidence-as-percentage",
    claim: /confidence[^.\n]{0,40}\d+\s?%|\d+\s?%[^.\n]{0,24}confidence/i,
    refuted: /\bnever\b|\bnot\b|must not|forbidden/i,
    why:
      "Confidence reaches the reader only as one of four EvidenceConfidenceBand " +
      "labels, never as a percentage",
  },
];

function readCurrentDocuments(): ReadonlyMap<string, string> {
  const entries = new Map<string, string>();
  for (const name of readdirSync(currentDir)) {
    if (!name.endsWith(".md")) continue;
    entries.set(name, readFileSync(path.join(currentDir, name), "utf8"));
  }
  return entries;
}

/** A sentence, plus only the context that is allowed to refute it. */
interface Claimable {
  readonly sentence: string;
  readonly line: number;
  readonly refutableBy: string;
}

const LIST_OR_ROW = /^\s*(?:[-*+]\s|\d+\.\s|\|)/;

/**
 * Markdown emphasis must not hide a denial: "not **end-to-end encryption**"
 * has to read as a refutation of "end-to-end encryption".
 */
function normalise(text: string): string {
  return text.replace(/[*`]+/g, "").replace(/\s+/g, " ");
}

/**
 * Splits a document into sentences and records, for each one, the text that may
 * legitimately refute a claim inside it: the sentence itself always, plus the
 * enclosing heading and the paragraph introducing the list when the sentence is
 * a list item or a table row.
 */
function claimables(text: string): Claimable[] {
  const lines = text.split("\n");
  const units: Claimable[] = [];
  let heading = "";
  let leadIn = "";
  let block: { lines: string[]; start: number } | null = null;

  const flush = () => {
    if (block === null) return;
    const isList = LIST_OR_ROW.test(block.lines[0]);
    const groups: { text: string; line: number }[] = [];
    if (isList) {
      let current: { text: string; line: number } | null = null;
      block.lines.forEach((line, offset) => {
        if (LIST_OR_ROW.test(line) || current === null) {
          if (current !== null) groups.push(current);
          current = { text: line, line: block!.start + offset };
        } else {
          current.text += ` ${line.trim()}`;
        }
      });
      if (current !== null) groups.push(current);
    } else {
      groups.push({ text: block.lines.join(" "), line: block.start });
    }

    for (const group of groups) {
      for (const sentence of group.text.split(/(?<=[.:;!?])\s+/)) {
        if (sentence.trim() === "") continue;
        units.push({
          sentence,
          line: group.line,
          refutableBy: isList
            ? [sentence, heading, leadIn].join("\n")
            : [sentence, heading].join("\n"),
        });
      }
    }
    if (!isList) leadIn = block.lines.join(" ");
    block = null;
  };

  lines.forEach((line, index) => {
    if (line.startsWith("#")) {
      flush();
      heading = line;
      leadIn = "";
      units.push({ sentence: line, line: index + 1, refutableBy: line });
      return;
    }
    if (line.trim() === "") {
      flush();
      return;
    }
    if (block === null) block = { lines: [line], start: index + 1 };
    else block.lines.push(line);
  });
  flush();
  return units;
}

function violations(rule: DriftRule, text: string): string[] {
  return claimables(text)
    .filter(
      (unit) =>
        rule.claim.test(normalise(unit.sentence)) &&
        !rule.refuted.test(normalise(unit.refutableBy)),
    )
    .map((unit) => `line ${unit.line}: ${unit.sentence.trim()}`);
}

/**
 * Every snake_case identifier in the document, backticked or bare. Bare tokens
 * count: an invented entitlement is drift whether or not it is code-formatted.
 * File and path segments are skipped — `archive_me_entitlement_matrix.json` is
 * a manifest name, not a claimed entitlement.
 */
function snakeCaseTokens(text: string): string[] {
  const tokens: string[] = [];
  for (const match of text.matchAll(/[a-z0-9]+(?:_[a-z0-9]+)+/g)) {
    const start = match.index ?? 0;
    const before = text.slice(Math.max(0, start - 1), start);
    const after = text.slice(start + match[0].length);
    if (before === "/" || before === "_" || /^[._/]/.test(after)) continue;
    tokens.push(match[0]);
  }
  return tokens;
}

function readJson(relativePath: string): Record<string, unknown> {
  return JSON.parse(readFileSync(path.join(root, relativePath), "utf8"));
}

test("docs/current contains exactly the authoritative documents", () => {
  const names = readdirSync(currentDir).sort();
  assert.deepEqual(names, ALLOWED_CURRENT_DOCUMENTS);
});

test("every docs/history file carries the non-authoritative banner", () => {
  const names = readdirSync(historyDir).filter((name) => name.endsWith(".md"));
  assert.ok(names.length > 0, "docs/history must not be empty");
  const missing = names.filter(
    (name) =>
      !readFileSync(path.join(historyDir, name), "utf8").startsWith(
        HISTORY_BANNER,
      ),
  );
  assert.deepEqual(
    missing,
    [],
    `docs/history files missing the non-authoritative banner: ${missing.join(", ")}`,
  );
});

test("docs/history explains that it is not authoritative", () => {
  const readme = readFileSync(path.join(historyDir, "README.md"), "utf8");
  assert.match(readme, /non-authoritative/i);
  assert.match(readme, /docs\/current/);
});

test("docs/current never points at docs/history as current documentation", () => {
  for (const [name, text] of readCurrentDocuments()) {
    assert.ok(
      !text.includes("docs/history"),
      `${name} references docs/history, which is non-authoritative`,
    );
  }
});

for (const rule of FORBIDDEN_CLAIMS) {
  test(`docs/current makes no unrefuted claim: ${rule.id}`, () => {
    const failures: string[] = [];
    for (const [name, text] of readCurrentDocuments()) {
      for (const hit of violations(rule, text)) {
        failures.push(`docs/current/${name} ${hit}`);
      }
    }
    assert.deepEqual(failures, [], `${rule.why}\n${failures.join("\n")}`);
  });
}

test("docs/current names only entitlement identifiers that exist in the manifests", () => {
  const matrix = readJson(
    "config/monetization/archive_me_entitlement_matrix.json",
  ) as {
    revenueCat: {
      canonicalProEntitlementId: string;
      acceptedLegacyEntitlementAliases: string[];
      legacyGrandfatheredProductIds: string[];
    };
    plans: { id: string }[];
  };
  const identity = readJson("config/release/archive_me_identity.json") as {
    revenueCat: { entitlementId: string; legacyEntitlementAliases: string[] };
  };
  const allowed = new Set<string>([
    matrix.revenueCat.canonicalProEntitlementId,
    ...matrix.revenueCat.acceptedLegacyEntitlementAliases,
    ...matrix.revenueCat.legacyGrandfatheredProductIds,
    ...matrix.plans.map((plan) => plan.id),
    identity.revenueCat.entitlementId,
    ...identity.revenueCat.legacyEntitlementAliases,
  ]);

  const failures: string[] = [];
  for (const [name, text] of readCurrentDocuments()) {
    for (const token of snakeCaseTokens(text)) {
      const segments = token.split("_");
      if (!segments.includes("pro") && !segments.includes("entitlement")) continue;
      if (allowed.has(token)) continue;
      failures.push(`docs/current/${name} names unknown entitlement \`${token}\``);
    }
  }
  assert.deepEqual(
    failures,
    [],
    `Allowed entitlement identifiers: ${[...allowed].sort().join(", ")}\n${failures.join("\n")}`,
  );
});

test("docs/current names only identifiers recorded in archive_me_identity.json", () => {
  const identity = readJson("config/release/archive_me_identity.json");
  const recorded = new Set(
    [...JSON.stringify(identity).matchAll(/com\.voicememory\.[A-Za-z0-9.]+/g)].map(
      (match) => match[0].replace(/\.+$/, ""),
    ),
  );
  assert.ok(
    recorded.has("com.voicememory.mobile"),
    "archive_me_identity.json must record the canonical identifier",
  );

  const failures: string[] = [];
  for (const [name, text] of readCurrentDocuments()) {
    for (const unit of claimables(text)) {
      for (const match of normalise(unit.sentence).matchAll(
        /com\.voicememory\.[A-Za-z0-9.]+/g,
      )) {
        const token = match[0].replace(/\.+$/, "");
        if (recorded.has(token)) continue;
        if (IDENTIFIER_DISCLAIMER.test(normalise(unit.refutableBy))) continue;
        failures.push(
          `docs/current/${name} line ${unit.line} uses unrecorded identifier ${token}`,
        );
      }
    }
  }
  assert.deepEqual(failures, [], failures.join("\n"));
});

test("docs/current states the canonical bundle identifier and no other", () => {
  const identity = readJson("config/release/archive_me_identity.json") as {
    ios: { bundleId: string };
    android: { applicationId: string };
  };
  const canonical = identity.ios.bundleId;
  assert.equal(identity.android.applicationId, canonical);

  // Any reverse-DNS identifier, not just a com.voicememory.* one, so that a
  // foreign bundle id such as com.example.app cannot slip through.
  const assertion =
    /(?:bundle\s+id(?:entifier)?|application\s+id|package\s+name)\b[^\n]{0,40}?\b([a-z][a-z0-9]*(?:\.[a-z0-9][A-Za-z0-9]*){2,})/gi;
  const failures: string[] = [];
  for (const [name, text] of readCurrentDocuments()) {
    for (const unit of claimables(text)) {
      for (const match of normalise(unit.sentence).matchAll(assertion)) {
        const token = match[1].replace(/\.+$/, "");
        if (token === canonical) continue;
        if (IDENTIFIER_DISCLAIMER.test(normalise(unit.refutableBy))) continue;
        failures.push(
          `docs/current/${name} line ${unit.line} asserts bundle identifier ${token}, expected ${canonical}`,
        );
      }
    }
  }
  assert.deepEqual(failures, [], failures.join("\n"));
});

test("the privacy document states the honest encryption and processing position", () => {
  const text = readFileSync(
    path.join(currentDir, "DATA_FLOW_AND_PRIVACY.md"),
    "utf8",
  );
  assert.match(text, /secure storage/i, "must describe platform secure storage");
  assert.match(text, /\/api\/transcribe/, "must name the remote transcription route");
  assert.match(text, /\/api\/analyze/, "must name the remote analysis route");
  assert.match(
    text,
    /not\s+end[\s-]to[\s-]end\s+encrypt/i,
    "must deny end-to-end encryption explicitly",
  );
  assert.match(
    text,
    /client[\s-]side/i,
    "must describe sync as client-side encrypted",
  );
  assert.match(
    text,
    /not\s+local[\s-]only/i,
    "must deny local-only processing explicitly",
  );
});

test("the product contract states one conclusion and a confidence band", () => {
  const text = readFileSync(path.join(currentDir, "PRODUCT_CONTRACT.md"), "utf8");
  assert.match(text, /at most\s+\*{0,2}one\*{0,2}\s+validated interpretation/i);
  for (const band of [
    "Early observation",
    "Some supporting evidence",
    "Repeated across moments",
    "Strongly supported",
  ]) {
    assert.ok(text.includes(band), `missing confidence band label: ${band}`);
  }
  assert.match(
    text,
    /never\s+(?:as\s+)?a\s+(?:confidence\s+)?(?:number|percentage)/i,
    "must state that confidence is never shown as a number",
  );
});

test("the architecture document states physical archive partitioning", () => {
  const text = readFileSync(path.join(currentDir, "ARCHITECTURE.md"), "utf8");
  assert.match(text, /ownerArchiveId/);
  assert.match(text, /ArchiveScopePaths/);
  assert.match(text, /partition/i);
});

test("every device gate in the accessibility document is BLOCKED_EXTERNAL", () => {
  const text = readFileSync(
    path.join(currentDir, "ACCESSIBILITY_DEVICE_VERIFICATION.md"),
    "utf8",
  );
  const lines = text.split("\n");
  const gateHeadings = lines.filter((line) => /^##\s+\d+\./.test(line));
  assert.equal(
    gateHeadings.length,
    7,
    `expected seven numbered device gates, found ${gateHeadings.length}`,
  );
  for (const keyword of [
    /VoiceOver/i,
    /TalkBack/i,
    /microphone permission/i,
    /Backgrounding during recording/i,
    /Keyboard navigation/i,
    /Dynamic Type/i,
    /Reduced motion/i,
  ]) {
    assert.ok(
      gateHeadings.some((heading) => keyword.test(heading)),
      `missing device gate heading for ${keyword}`,
    );
  }
  lines.forEach((line, index) => {
    if (!/^##\s+\d+\./.test(line)) return;
    const window = lines.slice(index, index + 6).join("\n");
    assert.match(
      window,
      /BLOCKED_EXTERNAL/,
      `gate "${line.trim()}" must be marked BLOCKED_EXTERNAL`,
    );
  });
  assert.match(
    text,
    /a written script is not device proof/i,
    "must state plainly that a script is not device proof",
  );
});

test("the release checklist reports no external gate as passed", () => {
  const text = readFileSync(path.join(currentDir, "RELEASE_CHECKLIST.md"), "utf8");
  assert.match(text, /BLOCKED_EXTERNAL/);
  assert.ok(
    !/- \[[xX]\]/.test(text),
    "no manual release blocker may be pre-ticked",
  );
  assert.ok(text.includes("- [ ]"), "manual blockers must remain unchecked");
});
