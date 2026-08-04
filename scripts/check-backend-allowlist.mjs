#!/usr/bin/env node
// Release guard: fails when a backend route becomes addressable in production
// without being listed in the V1 backend allowlist.
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const POLICY_PATH = "config/release/archive_me_v1_backend_allowlist.json";
const VALID_ALLOWED = new Set([
  "RETAIN_V1",
  "INTERNAL_REQUIRED",
  "MIGRATION_ONLY",
]);
const VALID_REMOVED = new Set(["MOVE_TO_EXPERIMENTS", "DELETE_OBSOLETE"]);

const failures = [];
const policy = JSON.parse(await readFile(path.join(root, POLICY_PATH), "utf8"));

const routeRoot = policy.guard?.routeRoot ?? "app/api";
const appRoot = path.join(root, path.dirname(routeRoot));

const allowlisted = new Map();
for (const entry of policy.routes ?? []) {
  if (allowlisted.has(entry.path)) {
    failures.push(`${POLICY_PATH}: duplicate allowlisted route ${entry.path}`);
  }
  if (!VALID_ALLOWED.has(entry.classification)) {
    failures.push(
      `${POLICY_PATH}: ${entry.path} has classification ${entry.classification}, which may not be addressable in production`,
    );
  }
  if (!(entry.capabilityGroup in (policy.capabilityGroups ?? {}))) {
    failures.push(
      `${POLICY_PATH}: ${entry.path} references unknown capability group ${entry.capabilityGroup}`,
    );
  }
  allowlisted.set(entry.path, entry);
}

const removed = new Map();
for (const entry of policy.removed ?? []) {
  if (!VALID_REMOVED.has(entry.classification)) {
    failures.push(
      `${POLICY_PATH}: removed route ${entry.path} has invalid classification ${entry.classification}`,
    );
  }
  if (allowlisted.has(entry.path)) {
    failures.push(
      `${POLICY_PATH}: ${entry.path} is listed as both allowlisted and removed`,
    );
  }
  removed.set(entry.path, entry);
}

const discovered = (await routeFiles(path.join(root, routeRoot)))
  .map((file) => `/${path.relative(appRoot, path.dirname(file)).split(path.sep).join("/")}`)
  .sort();

for (const route of discovered) {
  if (allowlisted.has(route)) continue;
  if (removed.has(route)) {
    failures.push(
      `route ${route} is classified ${removed.get(route).classification} but a handler is addressable under ${routeRoot}`,
    );
    continue;
  }
  failures.push(
    `route ${route} is addressable under ${routeRoot} but absent from ${POLICY_PATH}`,
  );
}

for (const route of allowlisted.keys()) {
  if (!discovered.includes(route)) {
    failures.push(`allowlisted route ${route} has no handler under ${routeRoot}`);
  }
}

// A route file is not the only way to become addressable. The custom server
// entry point can attach a WebSocket upgrade for a path whose Next.js handler
// has been held out, which would put an experimental surface back on the wire.
const SERVER_ENTRY = "server.entry.ts";
const forbiddenUpgrades = [
  { symbol: "attachLiveAudioWebSocketUpgrade", route: "/api/live-audio/ws" },
  { symbol: "attachCloudRelayWebSocketUpgrade", route: "/api/sync-relay/ws" },
];
const serverEntry = await readFile(path.join(root, SERVER_ENTRY), "utf8");
for (const { symbol, route } of forbiddenUpgrades) {
  const attached = serverEntry
    .split("\n")
    .some((line) => !line.trimStart().startsWith("//") && line.includes(symbol));
  if (attached) {
    failures.push(
      `${SERVER_ENTRY} attaches ${symbol}, which makes ${route} addressable outside ${POLICY_PATH}`,
    );
  }
}

if (failures.length > 0) {
  console.error(`backend allowlist guard FAILED (${failures.length} problem(s)):`);
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}

const byClassification = discovered.reduce((acc, route) => {
  const key = allowlisted.get(route).classification;
  acc[key] = (acc[key] ?? 0) + 1;
  return acc;
}, {});
console.log(
  `backend allowlist ok: ${discovered.length} addressable route(s) (${Object.entries(
    byClassification,
  )
    .map(([key, count]) => `${key}=${count}`)
    .sort()
    .join(", ")}); ${removed.size} route(s) held out of the release surface`,
);

async function routeFiles(directory) {
  const found = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      found.push(...(await routeFiles(absolute)));
    } else if (entry.name === "route.ts" || entry.name === "route.js") {
      found.push(absolute);
    }
  }
  return found;
}
