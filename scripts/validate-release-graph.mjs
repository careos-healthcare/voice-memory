#!/usr/bin/env node
import { access, readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const releaseRoot = path.join(root, ".backend-release");
const artifactMode = process.argv.includes("--artifact");
const failures = [];
const policy = JSON.parse(
  await read("config/release/backend-capabilities.json"),
);

const classifiedRoutes = Object.entries(policy.capabilityGroups).flatMap(
  ([group, routes]) => routes.map((route) => ({ group, route })),
);
const routeNames = classifiedRoutes.map(({ route }) => route);
const duplicateRoutes = routeNames.filter(
  (route, index) => routeNames.indexOf(route) !== index,
);
if (duplicateRoutes.length > 0) {
  failures.push(
    `routes classified more than once: ${duplicateRoutes.join(", ")}`,
  );
}

const sourceRoutes = (await routeFiles(path.join(root, "app/api")))
  .map((file) => {
    const directory = path.dirname(path.relative(path.join(root, "app"), file));
    return `/${directory.split(path.sep).join("/")}`;
  })
  .sort();
const allowedRoutes = [...routeNames].sort();
for (const route of sourceRoutes.filter(
  (route) => !allowedRoutes.includes(route),
)) {
  failures.push(`unclassified backend route: ${route}`);
}
for (const route of allowedRoutes.filter(
  (route) => !sourceRoutes.includes(route),
)) {
  failures.push(`classified route has no handler: ${route}`);
}

const authoritativeWorkflow = ".github/workflows/build_and_deploy.yml";
const workflow = await read(authoritativeWorkflow);
for (const marker of [
  "npm run validate:release-graph",
  "npm run build:backend",
  "npm run validate:backend-release",
  "npm install --global npm@11.6.2",
  "npm ci",
  "flutter pub get --enforce-lockfile",
  "build_android:",
  "build_ios:",
]) {
  if (!workflow.includes(marker)) {
    failures.push(`${authoritativeWorkflow} missing ${marker}`);
  }
}

for (const file of await workflowFiles()) {
  if (file === authoritativeWorkflow) continue;
  const source = await read(file);
  if (source.includes("workflow_dispatch:")) {
    failures.push(`duplicate manually dispatched release workflow: ${file}`);
  }
}

for (const file of await workflowFiles()) {
  const source = await read(file);
  for (const match of source.matchAll(/^\s*uses:\s*([^\s#]+)/gm)) {
    if (!/@[a-f0-9]{40}$/.test(match[1])) {
      failures.push(`${file} has mutable action reference: ${match[1]}`);
    }
  }
}

const packageManifest = JSON.parse(await read("package.json"));
if (packageManifest.packageManager !== "npm@11.6.2") {
  failures.push("package.json must pin packageManager to npm@11.6.2");
}
if (packageManifest.engines?.node !== ">=22.22.0") {
  failures.push("package.json must require Node >=22.22.0");
}
for (const [name, expected] of Object.entries({
  next: "16.2.12",
  sharp: "0.35.3",
})) {
  if (packageManifest.dependencies?.[name] !== expected) {
    failures.push(`package.json must pin ${name} to ${expected}`);
  }
}
for (const [name, expected] of Object.entries({
  "form-data": "2.5.6",
  postcss: "8.5.25",
  "websocket-driver": "0.7.5",
})) {
  if (packageManifest.overrides?.[name] !== expected) {
    failures.push(`package.json must override ${name} to ${expected}`);
  }
}
if (packageManifest.overrides?.sharp !== "$sharp") {
  failures.push(
    "package.json must apply the pinned sharp dependency across the tree",
  );
}

const dockerfile = await read("Dockerfile");
if (!dockerfile.includes("npm run build:backend")) {
  failures.push("Dockerfile does not build the authoritative backend artifact");
}
if (/RUN\s+npm run build(?:\s|$)/m.test(dockerfile)) {
  failures.push(
    "Dockerfile still compiles the customer Next.js web application",
  );
}

if (await exists("scripts/build_production.sh")) {
  failures.push(
    "duplicate local release script still exists: scripts/build_production.sh",
  );
}

if (artifactMode) {
  const appEntries = await readdir(path.join(releaseRoot, "app"));
  const unexpectedEntries = appEntries.filter((entry) => entry !== "api");
  if (unexpectedEntries.length > 0) {
    failures.push(
      `customer app entries leaked into backend artifact: ${unexpectedEntries.join(", ")}`,
    );
  }

  for (const excluded of [
    "components",
    "public",
    "apps",
    "android",
    "ios",
    "capacitor.config.ts",
  ]) {
    if (await exists(path.join(".backend-release", excluded))) {
      failures.push(
        `excluded client shell leaked into backend artifact: ${excluded}`,
      );
    }
  }

  const appPaths = JSON.parse(
    await read(".backend-release/.next/server/app-paths-manifest.json"),
  );
  for (const route of Object.keys(appPaths)) {
    if (
      !route.startsWith("/api/") &&
      route !== "/_not-found/page" &&
      route !== "/_global-error/page"
    ) {
      failures.push(
        `non-API Next.js route compiled into backend artifact: ${route}`,
      );
    }
  }

  for (const file of await manifestFiles(path.join(releaseRoot, ".next"))) {
    const manifest = JSON.parse(await readFile(file, "utf8"));
    for (const tracedFile of manifest.files ?? []) {
      const resolved = path.resolve(path.dirname(file), tracedFile);
      for (const forbiddenRoot of [
        path.join(root, "components"),
        path.join(root, "apps"),
        path.join(root, "android"),
        path.join(root, "ios"),
      ]) {
        if (
          resolved === forbiddenRoot ||
          resolved.startsWith(`${forbiddenRoot}${path.sep}`)
        ) {
          failures.push(
            `${path.relative(root, file)} traces excluded client source ${path.relative(root, resolved)}`,
          );
        }
      }
      if (
        resolved.startsWith(`${path.join(root, "app")}${path.sep}`) &&
        !resolved.startsWith(`${path.join(releaseRoot, "app/api")}${path.sep}`)
      ) {
        failures.push(
          `${path.relative(root, file)} traces customer app source ${path.relative(root, resolved)}`,
        );
      }
    }
  }
}

if (failures.length > 0) {
  console.error(`release graph validation failed:\n- ${failures.join("\n- ")}`);
  process.exit(1);
}

console.log(
  `release graph ok: ${sourceRoutes.length} routes in ${Object.keys(policy.capabilityGroups).length} capability groups${artifactMode ? "; API-only artifact verified" : ""}`,
);

async function read(relativePath) {
  return readFile(path.join(root, relativePath), "utf8");
}

async function exists(relativePath) {
  try {
    await access(
      path.isAbsolute(relativePath)
        ? relativePath
        : path.join(root, relativePath),
    );
    return true;
  } catch {
    return false;
  }
}

async function routeFiles(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...(await routeFiles(fullPath)));
    if (entry.isFile() && entry.name === "route.ts") files.push(fullPath);
  }
  return files;
}

async function workflowFiles() {
  const directory = path.join(root, ".github/workflows");
  return (await readdir(directory))
    .filter((file) => /\.ya?ml$/.test(file))
    .map((file) => `.github/workflows/${file}`);
}

async function manifestFiles(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...(await manifestFiles(fullPath)));
    if (entry.isFile() && entry.name.endsWith(".nft.json")) {
      files.push(fullPath);
    }
  }
  return files;
}
