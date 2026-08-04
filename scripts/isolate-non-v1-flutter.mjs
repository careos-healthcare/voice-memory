import { access, mkdir, readFile, readdir, rename } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const mobile = path.join(root, "apps/voicememory_mobile");
const mobileLib = path.join(mobile, "lib");
const reportPath = path.join(
  root,
  "artifacts/v1-architecture/v1-reachability-report.json",
);
const experimentRoot = path.join(root, "experiments/archive_me_legacy_flutter");

async function exists(file) {
  return access(file).then(
    () => true,
    () => false,
  );
}

async function filesUnder(directory, predicate) {
  const files = [];
  async function visit(current) {
    for (const entry of await readdir(current, {
      withFileTypes: true,
    }).catch(() => [])) {
      const absolute = path.join(current, entry.name);
      if (entry.isDirectory()) await visit(absolute);
      else if (predicate(absolute)) files.push(absolute);
    }
  }
  await visit(directory);
  return files.sort();
}

function importsFrom(source) {
  return [...source.matchAll(/^\s*(?:import|export|part)\s+['"]([^'"]+)['"]/gm)]
    .map((match) => match[1]);
}

function resolveDartImport(sourceFile, specifier) {
  if (specifier.startsWith("package:voicememory_mobile/")) {
    return path.join(
      mobileLib,
      specifier.slice("package:voicememory_mobile/".length),
    );
  }
  if (
    specifier.startsWith("dart:") ||
    specifier.startsWith("package:") ||
    specifier.startsWith("part of")
  ) {
    return null;
  }
  return path.resolve(path.dirname(sourceFile), specifier);
}

async function migrationClosure(allLibFiles) {
  const all = new Set(allLibFiles);
  const pending = allLibFiles.filter((file) =>
    /(?:^|[/_])(?:migration|migrations|legacy_adapter|legacy_subscription_mapper)(?:[/_.]|$)/i.test(
      path.relative(mobileLib, file),
    ),
  );
  const retained = new Set();
  while (pending.length) {
    const current = pending.pop();
    if (retained.has(current) || !all.has(current)) continue;
    retained.add(current);
    const source = await readFile(current, "utf8");
    for (const specifier of importsFrom(source)) {
      const resolved = resolveDartImport(current, specifier);
      if (resolved && all.has(resolved) && !retained.has(resolved)) {
        pending.push(resolved);
      }
    }
  }
  return retained;
}

async function localClosure(seedFiles, availableFiles) {
  const available = new Set(availableFiles);
  const pending = [...seedFiles];
  const retained = new Set();
  while (pending.length) {
    const current = pending.pop();
    if (retained.has(current) || !available.has(current)) continue;
    retained.add(current);
    const source = await readFile(current, "utf8");
    for (const specifier of importsFrom(source)) {
      const resolved = resolveDartImport(current, specifier);
      if (resolved && available.has(resolved) && !retained.has(resolved)) {
        pending.push(resolved);
      }
    }
  }
  return retained;
}

async function movePreserving(relativeFromRoot, destinationBase) {
  const source = path.join(root, relativeFromRoot);
  const destination = path.join(destinationBase, relativeFromRoot);
  if (await exists(destination)) {
    throw new Error(`Refusing to overwrite isolated file: ${destination}`);
  }
  await mkdir(path.dirname(destination), { recursive: true });
  await rename(source, destination);
}

if (process.argv.includes("--restore-all")) {
  const isolatedFiles = await filesUnder(experimentRoot, () => true);
  for (const source of isolatedFiles) {
    const relative = path.relative(experimentRoot, source);
    const destination = path.join(root, relative);
    if (await exists(destination)) {
      throw new Error(`Refusing to overwrite restored file: ${destination}`);
    }
    await mkdir(path.dirname(destination), { recursive: true });
    await rename(source, destination);
  }
  console.log(JSON.stringify({ restoredFiles: isolatedFiles.length }, null, 2));
  process.exit(0);
}

const report = JSON.parse(await readFile(reportPath, "utf8"));
if (report.status !== "PASS") {
  throw new Error(
    "Reachability report must pass before isolating non-release files.",
  );
}

const reachable = new Set(report.entryPoints.reachableDartFiles);
const allLibFiles = await filesUnder(mobileLib, (file) => file.endsWith(".dart"));
const migrationFiles = await migrationClosure(allLibFiles);
const contract = JSON.parse(
  await readFile(
    path.join(root, "config/product/archive_me_v1_release_contract.json"),
    "utf8",
  ),
);
const allTestFilesBeforeIsolation = (
  await Promise.all(
    [
      path.join(mobile, "test"),
      path.join(mobile, "integration_test"),
      path.join(mobile, "tool"),
    ].map((directory) =>
      filesUnder(directory, (file) => file.endsWith(".dart")),
    ),
  )
).flat();
const guardSeedFiles = contract.architectureGuardTests
  .map((file) => path.join(root, file))
  .filter((file) => allTestFilesBeforeIsolation.includes(file));
const guardClosure = await localClosure(guardSeedFiles, [
  ...allLibFiles,
  ...allTestFilesBeforeIsolation,
]);
const productionMoves = allLibFiles
  .filter((file) => {
    const relative = path.relative(root, file).replaceAll(path.sep, "/");
    return (
      !reachable.has(relative) &&
      !migrationFiles.has(file) &&
      !guardClosure.has(file)
    );
  })
  .map((file) => path.relative(root, file));

for (const relative of productionMoves) {
  await movePreserving(relative, experimentRoot);
}

// Tests for isolated product modules are retained as historical evidence, but
// no longer participate in Flutter analysis or release CI.
const testRoots = [
  path.join(mobile, "test"),
  path.join(mobile, "integration_test"),
  path.join(mobile, "tool"),
];
const testFiles = allTestFilesBeforeIsolation;
const movedTestFiles = new Set();
let changed = true;
while (changed) {
  changed = false;
  for (const file of testFiles) {
    if (movedTestFiles.has(file) || guardClosure.has(file)) continue;
    const source = await readFile(file, "utf8");
    for (const specifier of importsFrom(source)) {
      const resolved = resolveDartImport(file, specifier);
      if (!resolved) continue;
      if (!(await exists(resolved)) || movedTestFiles.has(resolved)) {
        movedTestFiles.add(file);
        changed = true;
        break;
      }
    }
  }
}
for (const file of [...movedTestFiles].sort()) {
  await movePreserving(path.relative(root, file), experimentRoot);
}

console.log(
  JSON.stringify(
    {
      productionDartFilesIsolated: productionMoves.length,
      migrationDartFilesRetained: migrationFiles.size,
      testDartFilesIsolated: movedTestFiles.size,
      destination: path.relative(root, experimentRoot),
    },
    null,
    2,
  ),
);
