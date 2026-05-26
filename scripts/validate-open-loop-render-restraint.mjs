#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCANNED = [
  "lib/open-loops/unresolved-signals.ts",
  "lib/open-loops/unresolved-detect-core.ts",
  "lib/open-loops/unresolved-cache.ts",
  "lib/open-loops/open-loop-continuity.ts",
  "lib/open-loops/open-loop-storage.ts",
  "components/entry/OpenLoopNextStepPrompt.tsx",
  "components/open-loops/OpenLoopEntryContinuity.tsx",
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

const failures = [];

for (const rel of SCANNED) {
  const filePath = path.join(ROOT, rel);
  if (!fs.existsSync(filePath)) {
    failures.push(`${rel}: missing`);
    continue;
  }
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

const entryPage = path.join(ROOT, "app/entry/[id]/page.tsx");
const entrySource = fs.readFileSync(entryPage, "utf8");
if (entrySource.includes("auditOpenLoopActivation(entry")) {
  failures.push("app/entry/[id]/page.tsx: remove auditOpenLoopActivation from render effects");
}

if (failures.length > 0) {
  console.error("Open loop render restraint validation failed:\n");
  for (const line of failures) console.error(`  ${line}`);
  process.exit(1);
}

console.log("Open loop render restraint validation passed.");
