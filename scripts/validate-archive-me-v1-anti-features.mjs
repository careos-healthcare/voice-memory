/**
 * Fails the release if a product direction V1 rejected has come back.
 *
 * Every check reads an explicit allowlist out of
 * config/product/archive_me_v1_contract.json: the two files that may declare a
 * route, the exact feature directory names that must stay empty, and the exact
 * copy sources that carry primary positioning. Nothing here scans the
 * repository for substrings, so a legitimate class, file, or directory whose
 * name merely contains a common word — lib/features/journal,
 * lib/features/memory, lib/features/chat_differentiation — is never flagged.
 */
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const violations = [];
const checks = [];

function fail(direction, detail) {
  violations.push(`${direction}: ${detail}`);
}

async function read(relativePath) {
  return readFile(path.join(root, relativePath), "utf8");
}

async function dartFilesUnder(directory) {
  const found = [];
  async function visit(current) {
    const entries = await readdir(current, { withFileTypes: true }).catch(
      () => [],
    );
    for (const entry of entries) {
      const absolute = path.join(current, entry.name);
      if (entry.isDirectory()) await visit(absolute);
      else if (entry.name.endsWith(".dart")) found.push(absolute);
    }
  }
  await visit(path.join(root, directory));
  return found.map((file) => path.relative(root, file).replaceAll(path.sep, "/"));
}

const contract = JSON.parse(
  await read("config/product/archive_me_v1_contract.json"),
);
const guard = contract.antiFeatureGuard;
const directions = new Map(
  contract.prohibitedProductDirections.map((entry) => [entry.id, entry.label]),
);

// ——— 1. No fifth primary tab ———
{
  const catalog = await read(
    "apps/voicememory_mobile/lib/router/route_catalog.dart",
  );
  const destinations = await read(
    "apps/voicememory_mobile/lib/router/primary_destination.dart",
  );
  const declared = catalog
    .match(/static const primaryRoutes = \[([^\]]*)\]/s)?.[1]
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean).length;
  const branches = [...destinations.matchAll(/route:\s*RouteCatalog\./g)].length;

  if (contract.allowedPrimaryRoutes.length !== guard.primaryTabCount) {
    fail("fifth-primary-tab", `contract declares ${contract.allowedPrimaryRoutes.length} primary routes`);
  }
  if (declared !== guard.primaryTabCount) {
    fail("fifth-primary-tab", `RouteCatalog.primaryRoutes declares ${declared} routes`);
  }
  if (branches !== guard.primaryTabCount) {
    fail("fifth-primary-tab", `PrimaryDestination declares ${branches} destinations`);
  }
  checks.push(`primary tabs: ${branches}`);
}

// ——— 2. No prohibited route may be declared ———
{
  const prohibited = new Set(guard.prohibitedRoutePaths);
  let declaredRoutes = 0;
  for (const source of guard.routeDeclarationSources) {
    const text = await read(source);
    for (const match of text.matchAll(/['"](\/[A-Za-z0-9_:\-/]*)['"]/g)) {
      declaredRoutes += 1;
      if (prohibited.has(match[1])) {
        fail("prohibited-route", `${source} declares ${match[1]}`);
      }
    }
  }
  checks.push(`route declarations scanned: ${declaredRoutes}`);
}

// ——— 3. Prohibited production modules must hold no Dart code ———
{
  const directories = [
    ...guard.prohibitedProductionFeatureDirectories.map(
      (name) => `${guard.productionFeatureRoot}/${name}`,
    ),
    ...guard.prohibitedProductionDirectories,
  ];
  const legitimate = new Set(guard.legitimateProductionDirectories);
  for (const directory of directories) {
    if (legitimate.has(directory)) {
      fail(
        "guard-configuration",
        `${directory} is listed as both prohibited and legitimate`,
      );
      continue;
    }
    const files = await dartFilesUnder(directory);
    if (files.length > 0) {
      fail("prohibited-module", `${directory} holds ${files.length} Dart file(s)`);
    }
  }
  // Named so the allowlist is checked, not merely documented: these directories
  // contain the very words the prohibited list uses and must keep their code.
  for (const directory of legitimate) {
    const files = await dartFilesUnder(directory);
    if (files.length === 0) {
      fail(
        "guard-configuration",
        `${directory} is allowlisted as legitimate but holds no Dart file`,
      );
    }
  }
  checks.push(
    `prohibited module directories: ${directories.length}, ` +
      `legitimate look-alikes kept: ${legitimate.size}`,
  );
}

// ——— 4. Positioning copy may not claim a rejected direction ———
{
  const denial = new RegExp(guard.claimDenial, "i");
  const prohibitedHeading = new RegExp(
    guard.prohibitedMarkdownSectionHeadings,
    "i",
  );
  const claims = guard.prohibitedPositioningClaims.map((claim) => ({
    id: claim.id,
    pattern: new RegExp(claim.pattern, "gi"),
  }));

  /** Sentences a reader would meet as a claim, with prohibition lists dropped. */
  function claimableSentences(source, text) {
    const markdown = source.endsWith(".md");
    const sentences = [];
    let skipping = false;
    for (const line of text.split("\n")) {
      if (markdown && line.startsWith("#")) {
        skipping = prohibitedHeading.test(line);
        continue;
      }
      if (skipping) continue;
      for (const sentence of line.split(/(?<=[.!?])\s+/)) {
        if (sentence.trim()) sentences.push(sentence);
      }
    }
    return sentences;
  }

  for (const source of guard.positioningCopySources) {
    const text = await read(source);
    for (const sentence of claimableSentences(source, text)) {
      for (const claim of claims) {
        claim.pattern.lastIndex = 0;
        for (const match of sentence.matchAll(claim.pattern)) {
          if (denial.test(sentence.slice(0, match.index))) continue;
          fail(
            claim.id,
            `${source} claims "${match[0]}" in: ${sentence.trim()}`,
          );
          break;
        }
      }
    }
  }
  checks.push(
    `positioning sources scanned: ${guard.positioningCopySources.length}`,
  );
}

// ——— 5. One journal model, no lifetime package ———
{
  if (contract.canonicalJournalModel !== guard.canonicalJournalModel) {
    fail("multiple-journals", "canonical journal model drifted from the guard");
  }
  const matrix = JSON.parse(await read(guard.monetizationMatrix));
  const blocked = new Set(matrix.revenueCat.blockedCurrentPackageKinds ?? []);
  for (const kind of guard.prohibitedMonetizationPackageKinds) {
    if (!blocked.has(kind)) {
      fail("lifetime-subscription", `${kind} is not blocked in the matrix`);
    }
    if ((matrix.revenueCat.currentOfferingPackageKinds ?? []).includes(kind)) {
      fail("lifetime-subscription", `${kind} is offered to new purchasers`);
    }
    for (const plan of matrix.plans ?? []) {
      if (plan.kind === kind && plan.availableForNewPurchase !== false) {
        fail("lifetime-subscription", `plan ${plan.id} sells ${kind}`);
      }
    }
  }
}

// ——— 6. Capability surface: packages and platform permissions ———
{
  const pubspec = await read("apps/voicememory_mobile/pubspec.yaml");
  const lock = await read("apps/voicememory_mobile/pubspec.lock");
  for (const packageName of guard.prohibitedPubspecPackages) {
    const declaration = new RegExp(`^  ${packageName}:`, "m");
    if (declaration.test(pubspec)) {
      fail("prohibited-package", `pubspec.yaml declares ${packageName}`);
    }
    if (declaration.test(lock)) {
      fail("prohibited-package", `pubspec.lock resolves ${packageName}`);
    }
  }

  const manifest = await read(
    "apps/voicememory_mobile/android/app/src/main/AndroidManifest.xml",
  );
  const active = [...manifest.matchAll(/<uses-permission\b[^>]*>/g)]
    .map((match) => match[0])
    .filter((tag) => !/tools:node\s*=\s*["']remove["']/.test(tag));
  for (const permission of guard.prohibitedAndroidPermissions) {
    if (active.some((tag) => tag.includes(`"${permission}"`))) {
      fail("platform-permission", `AndroidManifest keeps ${permission} active`);
    }
  }

  for (const plistPath of [
    "apps/voicememory_mobile/ios/Runner/Info.plist",
    "apps/voicememory_mobile/ios/Runner/Info-Release.plist",
  ]) {
    const plist = await read(plistPath);
    for (const key of guard.prohibitedIosPlistKeys) {
      if (plist.includes(`<key>${key}</key>`)) {
        fail("platform-permission", `${plistPath} declares ${key}`);
      }
    }
  }
  checks.push(
    `prohibited packages: ${guard.prohibitedPubspecPackages.length}, ` +
      `prohibited permissions: ${guard.prohibitedAndroidPermissions.length + guard.prohibitedIosPlistKeys.length}`,
  );
}

// ——— 7. Every rejected direction must name an enforcement mechanism ———
{
  const known = new Set([
    "primaryTabCount",
    "routeDeclarations",
    "productionFeatureDirectories",
    "positioningClaims",
    "forbiddenPrimaryHeadlines",
    "prohibitedPackages",
    "platformPermissions",
    "canonicalJournalModel",
    "monetizationPackageKinds",
  ]);
  for (const entry of contract.prohibitedProductDirections) {
    if (!entry.enforcedBy?.length) {
      fail("guard-configuration", `${entry.id} declares no enforcement`);
    }
    for (const mechanism of entry.enforcedBy ?? []) {
      if (!known.has(mechanism)) {
        fail("guard-configuration", `${entry.id} names unknown mechanism ${mechanism}`);
      }
    }
  }
  checks.push(`rejected directions encoded: ${directions.size}`);
}

if (violations.length) {
  console.error(violations.map((value) => `- ${value}`).join("\n"));
  process.exitCode = 1;
} else {
  console.log(`ArchiveMe V1 anti-feature guard passed: ${checks.join("; ")}.`);
}
