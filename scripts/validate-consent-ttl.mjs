#!/usr/bin/env node
/**
 * Guards the "one TTL declaration per role" invariant.
 *
 * The bug this exists to prevent: the caregiver and coach defaults used to be
 * written down twice each, once in the pure verification module and once in the
 * server crypto wrapper. Shortening one left the other as a live long-lived
 * path. Both defaults now live only in
 * `packages/shared/lib/consent/consent-token-ttl.ts`, and this script fails if a
 * second one reappears anywhere in the consent code.
 *
 * The same invariant has to hold across the language boundary. Dart mirrors of
 * these lifetimes are checked against the TypeScript declarations below; see
 * "Dart mirrors" further down for why that half exists.
 */
import { readdirSync, readFileSync, realpathSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { runConsentTokenTtlTests } from "../packages/shared/lib/consent/consent-token-ttl-tests.ts";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const CANONICAL_FILE = "packages/shared/lib/consent/consent-token-ttl.ts";

/** Every file allowed to mention a consent TTL at all. */
const SCANNED_FILES = [
  CANONICAL_FILE,
  "packages/shared/lib/caregiver/consent-verification.ts",
  "packages/shared/lib/coach/client-consent-verification.ts",
  "packages/shared/lib/server/caregiver-consent-crypto.ts",
  "packages/shared/lib/server/coach-consent-crypto.ts",
  "packages/shared/lib/server/consent-renewal-handler.ts",
  "apps/api/app/api/coach/consent/issue/route.ts",
  "apps/api/app/api/coach/consent/verify/route.ts",
  "apps/api/app/api/coach/consent/revoke/route.ts",
  // Renewal is the likeliest place for a second default to reappear: it is
  // tempting to write "extend by a week" here rather than issue through the
  // one caregiver default, and a window that is written down twice is a
  // window that can be lengthened in one place only.
  "apps/api/app/api/coach/consent/renew/route.ts",
];

/** `1000 * 60 * 60 * 24 * N`, `24 * 60 * 60 * 1000`, `N * DAY_MS`, `DEFAULT_TTL_MS = ...` */
const TTL_LITERAL_PATTERNS = [
  /\b1000\s*\*\s*60\s*\*\s*60\s*\*\s*24\b/,
  /\b24\s*\*\s*60\s*\*\s*60\s*\*\s*1000\b/,
  /\bDEFAULT_TTL_MS\s*=/,
  /ttlMs\s*\?\?\s*\d/,
];

const failures = [];

function readSource(relativePath) {
  try {
    return readFileSync(path.join(repoRoot, relativePath), "utf8");
  } catch {
    return null;
  }
}

// 1. No TTL literal outside the canonical module.
for (const relativePath of SCANNED_FILES) {
  if (relativePath === CANONICAL_FILE) continue;
  const source = readSource(relativePath);
  if (source == null) {
    failures.push(`${relativePath}: expected file is missing`);
    continue;
  }

  const lines = source.split("\n");
  lines.forEach((line, index) => {
    if (line.trimStart().startsWith("*") || line.trimStart().startsWith("//")) return;
    for (const pattern of TTL_LITERAL_PATTERNS) {
      if (pattern.test(line)) {
        failures.push(
          `${relativePath}:${index + 1}: a consent TTL default may only be declared in ${CANONICAL_FILE} — found ${line.trim()}`,
        );
      }
    }
  });
}

// 2. Exactly one declaration per role in the canonical module.
const canonical = readSource(CANONICAL_FILE);
if (canonical == null) {
  failures.push(`${CANONICAL_FILE} is missing`);
} else {
  for (const name of [
    "CAREGIVER_CONSENT_DEFAULT_TTL_MS",
    "COACH_CONSENT_DEFAULT_TTL_MS",
  ]) {
    const declarations = canonical.match(
      new RegExp(`export const ${name}\\s*=`, "g"),
    );
    if ((declarations?.length ?? 0) !== 1) {
      failures.push(
        `${CANONICAL_FILE}: expected exactly one declaration of ${name}, found ${declarations?.length ?? 0}`,
      );
    }
  }
}

// 3. Both issue paths resolve through the shared helpers.
const issuePaths = [
  ["packages/shared/lib/caregiver/consent-verification.ts", "resolveCaregiverConsentTtlMs"],
  ["packages/shared/lib/coach/client-consent-verification.ts", "resolveCoachConsentTtlMs"],
];
for (const [relativePath, helper] of issuePaths) {
  const source = readSource(relativePath);
  if (source == null || !source.includes(`${helper}(options.ttlMs)`)) {
    failures.push(
      `${relativePath}: token issuance must resolve its TTL through ${helper}(options.ttlMs)`,
    );
  }
}

// 4. Dart mirrors agree with the TypeScript declarations.
//
// `ClientConsentVerificationService.issueToken` defaulted to a 90-day coach TTL
// while `COACH_CONSENT_DEFAULT_TTL_MS` said 30. Nothing caught it, because this
// script only ever read TypeScript. A duplicated default is a default that can
// be shortened in one place only, and the language boundary is just another
// place to duplicate it.
//
// TypeScript is authoritative. A Dart value that disagrees is the wrong one.

/** `1000 * 60 * 60 * 24 * 7` -> 604800000. Null if not a product of literals. */
function evaluateLiteralProduct(expression) {
  const factors = expression.split("*").map((part) => Number(part.trim()));
  if (factors.some((factor) => !Number.isFinite(factor))) return null;
  return factors.reduce((a, b) => a * b, 1);
}

/** The authoritative lifetimes, read from the canonical module rather than restated. */
const canonicalTtlMs = new Map();
if (canonical != null) {
  for (const name of [
    "CAREGIVER_CONSENT_DEFAULT_TTL_MS",
    "COACH_CONSENT_DEFAULT_TTL_MS",
  ]) {
    const declaration = canonical.match(
      new RegExp(`export const ${name}\\s*=\\s*([0-9*\\s]+);`),
    );
    const ms = declaration ? evaluateLiteralProduct(declaration[1]) : null;
    if (ms == null) {
      failures.push(
        `${CANONICAL_FILE}: ${name} is no longer declared as a product of integer literals, so the Dart mirrors cannot be checked against it`,
      );
      continue;
    }
    canonicalTtlMs.set(name, ms);
  }
}

/**
 * Dart roots to walk. `retired_sprawl/` is analyzer-excluded but shipped, and
 * 373 of the entries under `lib/features/` are symlinks into it — so the coach
 * consent service is reachable by two paths and must be counted once.
 *
 * A missing root is a failure, not a skip. Three checks in this repo were found
 * reporting success while reading zero files, one of them because its directory
 * walk did `if (!dir.existsSync()) continue`.
 */
const DART_SCAN_ROOTS = [
  "apps/mobile/lib",
  "apps/mobile/test",
  "apps/mobile/retired_sprawl",
  "apps/mobile/integration_test",
];

const DART_SKIP_DIRS = new Set([".dart_tool", "build", ".git", "node_modules"]);

/**
 * Every `.dart` file under `roots`, following symlinks, one entry per realpath.
 *
 * Returns realpaths so that `lib/features/coach/...` and
 * `retired_sprawl/lib_features/coach/...` — the same bytes — are one file.
 */
function collectDartFiles(roots) {
  const byRealPath = new Map();
  const visitedDirs = new Set();
  const missingRoots = [];

  function walk(dir) {
    let realDir;
    try {
      realDir = realpathSync(dir);
    } catch {
      return; // broken symlink
    }
    if (visitedDirs.has(realDir)) return; // symlink cycle, or a second route in
    visitedDirs.add(realDir);

    let entries;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      if (entry.name.startsWith(".") && entry.name !== ".") continue;
      if (DART_SKIP_DIRS.has(entry.name)) continue;
      const child = path.join(dir, entry.name);

      // `isDirectory()` is false for a symlink to a directory, so stat through it.
      let stats;
      try {
        stats = statSync(child);
      } catch {
        continue; // broken symlink
      }

      if (stats.isDirectory()) {
        walk(child);
      } else if (stats.isFile() && entry.name.endsWith(".dart")) {
        try {
          byRealPath.set(realpathSync(child), true);
        } catch {
          /* raced away underneath us */
        }
      }
    }
  }

  for (const root of roots) {
    const absolute = path.join(repoRoot, root);
    try {
      if (!statSync(absolute).isDirectory()) {
        missingRoots.push(root);
        continue;
      }
    } catch {
      missingRoots.push(root);
      continue;
    }
    walk(absolute);
  }

  return { files: [...byRealPath.keys()].sort(), missingRoots };
}

/**
 * Overwrites comments with spaces, preserving every byte offset and newline.
 *
 * Offsets still map onto the original file, so line numbers stay reportable
 * while a TTL mentioned only in prose cannot trip the scan.
 */
function blankDartComments(source) {
  const out = source.split("");
  let i = 0;
  const blank = (from, to) => {
    for (let j = from; j < to && j < out.length; j += 1) {
      if (out[j] !== "\n") out[j] = " ";
    }
  };

  while (i < source.length) {
    const two = source.slice(i, i + 2);
    const three = source.slice(i, i + 3);

    if (two === "//") {
      const end = source.indexOf("\n", i);
      blank(i, end === -1 ? source.length : end);
      i = end === -1 ? source.length : end;
      continue;
    }
    if (two === "/*") {
      const end = source.indexOf("*/", i + 2);
      const stop = end === -1 ? source.length : end + 2;
      blank(i, stop);
      i = stop;
      continue;
    }
    if (three === "'''" || three === '"""') {
      const end = source.indexOf(three, i + 3);
      i = end === -1 ? source.length : end + 3;
      continue;
    }
    if (two[0] === "'" || two[0] === '"') {
      const quote = two[0];
      let j = i + 1;
      while (j < source.length && source[j] !== quote) {
        if (source[j] === "\\") j += 1;
        if (source[j] === "\n") break;
        j += 1;
      }
      i = j + 1;
      continue;
    }
    i += 1;
  }

  return out.join("");
}

const DART_DURATION_UNIT_MS = {
  days: 86400000,
  hours: 3600000,
  minutes: 60000,
  seconds: 1000,
  milliseconds: 1,
};

/** `days: 30, hours: 2` -> 2599200000. Null if any argument is not an integer literal. */
function evaluateDartDuration(argumentList) {
  if (argumentList.trim() === "") return null;
  let total = 0;
  for (const argument of argumentList.split(",")) {
    if (argument.trim() === "") continue;
    const [unit, rawValue] = argument.split(":");
    const unitMs = DART_DURATION_UNIT_MS[unit?.trim()];
    const value = Number(rawValue?.trim());
    if (unitMs == null || !Number.isInteger(value)) return null;
    total += unitMs * value;
  }
  return total;
}

/**
 * Which lifetime a Dart declaration is mirroring, from its location.
 *
 * Path rather than a nearby comment: a comment can be deleted without changing
 * behaviour, and a guard that goes quiet when someone tidies prose is worse
 * than no guard.
 */
function consentRoleFor(relativePath) {
  if (/(^|\/)coach(\/|_)|coach_consent|client_consent/.test(relativePath)) {
    return "COACH_CONSENT_DEFAULT_TTL_MS";
  }
  if (/(^|\/)caregiver(\/|_)|caregiver_consent|monitoring_consent/.test(relativePath)) {
    return "CAREGIVER_CONSENT_DEFAULT_TTL_MS";
  }
  return null;
}

const { files: dartFiles, missingRoots } = collectDartFiles(DART_SCAN_ROOTS);

for (const root of missingRoots) {
  failures.push(
    `Dart scan root ${root} is missing — if the tree moved, repoint DART_SCAN_ROOTS rather than letting the scan quietly cover nothing`,
  );
}

if (dartFiles.length === 0) {
  failures.push(
    "the Dart scan matched no files; a consent check that reads nothing reports success for the wrong reason",
  );
}

let dartTtlDeclarations = 0;
for (const absolutePath of dartFiles) {
  const relativePath = path.relative(repoRoot, absolutePath);
  let source;
  try {
    source = readFileSync(absolutePath, "utf8");
  } catch {
    continue;
  }
  if (!/\bttl\b/i.test(source)) continue;

  const code = blankDartComments(source);
  const durationCall = /\bDuration\s*\(([^)]*)\)/g;
  let match;
  while ((match = durationCall.exec(code)) !== null) {
    // A `Duration` is a consent lifetime only if a `ttl` identifier binds it.
    // The window reaches back far enough to survive a wrapped declaration.
    const preceding = code.slice(Math.max(0, match.index - 120), match.index);
    if (!/\bttl\b/i.test(preceding)) continue;

    dartTtlDeclarations += 1;
    const line = code.slice(0, match.index).split("\n").length;
    const where = `${relativePath}:${line}`;

    const role = consentRoleFor(relativePath);
    if (role == null) {
      failures.push(
        `${where}: a consent TTL is declared here but the file is neither a coach nor a caregiver path, so it cannot be checked against ${CANONICAL_FILE} — move it or name it for its role`,
      );
      continue;
    }

    const expectedMs = canonicalTtlMs.get(role);
    if (expectedMs == null) continue; // already reported against the canonical file

    const actualMs = evaluateDartDuration(match[1]);
    if (actualMs == null) {
      failures.push(
        `${where}: consent TTL is not a Duration of integer literals, so it cannot be checked against ${role} — ${source.split("\n")[line - 1]?.trim() ?? ""}`,
      );
      continue;
    }

    if (actualMs !== expectedMs) {
      const days = (ms) => ms / DART_DURATION_UNIT_MS.days;
      failures.push(
        `${where}: consent TTL is ${days(actualMs)} days but ${role} in ${CANONICAL_FILE} is ${days(expectedMs)} days — TypeScript is authoritative; change the Dart value`,
      );
    }
  }
}

// The scan can only vouch for what it read. A walk that finds files but no
// declaration means the mirror moved out from under this check.
if (dartFiles.length > 0 && dartTtlDeclarations === 0) {
  failures.push(
    `scanned ${dartFiles.length} Dart files and found no consent TTL declaration; the mirror this check exists for is gone or unrecognisable, which is a failure and not a pass`,
  );
}

failures.push(...(await runConsentTokenTtlTests()).failures);

if (failures.length) {
  console.error("validate-consent-ttl failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log(
  `validate-consent-ttl ok — ${SCANNED_FILES.length} TypeScript files, ` +
    `${dartFiles.length} Dart files (deduplicated by realpath, symlinks followed), ` +
    `${dartTtlDeclarations} Dart consent TTL declaration(s) checked against ${CANONICAL_FILE}`,
);
