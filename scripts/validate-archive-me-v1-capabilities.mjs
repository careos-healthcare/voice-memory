import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const mobile = path.join(root, "apps/voicememory_mobile");
const contract = JSON.parse(
  await readFile(
    path.join(root, "config/product/archive_me_v1_capabilities.json"),
    "utf8",
  ),
);
const productContract = JSON.parse(
  await readFile(
    path.join(root, "config/product/archive_me_v1_contract.json"),
    "utf8",
  ),
);
const releaseContract = JSON.parse(
  await readFile(
    path.join(root, "config/product/archive_me_v1_release_contract.json"),
    "utf8",
  ),
);
const analyticsContract = JSON.parse(
  await readFile(path.join(root, releaseContract.analytics.catalog), "utf8"),
);
const monetizationContract = JSON.parse(
  await readFile(
    path.join(root, "config/monetization/archive_me_entitlement_matrix.json"),
    "utf8",
  ),
);

async function filesUnder(directory, predicate) {
  const files = [];
  async function visit(current) {
    for (const entry of await readdir(current, { withFileTypes: true }).catch(
      () => [],
    )) {
      const absolute = path.join(current, entry.name);
      if (entry.isDirectory()) await visit(absolute);
      else if (predicate(absolute)) files.push(absolute);
    }
  }
  await visit(directory);
  return files.sort();
}

function pubspecDependencies(source) {
  const result = [];
  let active = false;
  for (const line of source.split(/\r?\n/)) {
    if (line === "dependencies:") {
      active = true;
      continue;
    }
    if (active && /^[^\s]/.test(line) && line.trim()) break;
    const match = active ? line.match(/^  ([a-zA-Z0-9_]+):/) : null;
    if (match && match[1] !== "flutter") result.push(match[1]);
  }
  return result.sort();
}

function unique(values) {
  return [...new Set(values)].sort();
}

const violations = [];
if (
  productContract.allowedDependenciesManifest !==
    "config/product/archive_me_v1_capabilities.json" ||
  productContract.allowedAnalyticsEventsManifest !==
    "config/product/archive_me_v1_analytics_events.json" ||
  productContract.dataFlowManifest !==
    "config/privacy/archive_me_data_flow.json"
) {
  violations.push("primary V1 contract manifest references drifted");
}
if (
  JSON.stringify([...productContract.allowedPrimaryRoutes].sort()) !==
  JSON.stringify([...releaseContract.routes.primary].sort())
) {
  violations.push("primary V1 route contract differs from release contract");
}
if (
  productContract.canonicalRevenueCatEntitlementReference !==
  monetizationContract.revenueCat.canonicalProEntitlementId
) {
  violations.push("primary V1 RevenueCat entitlement reference drifted");
}
if (
  productContract.canonicalAppIdentities.iosBundleId !==
    releaseContract.identities.iosBundleId ||
  productContract.canonicalAppIdentities.androidApplicationId !==
    releaseContract.identities.androidApplicationId ||
  !releaseContract.identities.urlSchemes.includes(
    productContract.canonicalAppIdentities.urlScheme,
  )
) {
  violations.push("primary V1 app identities drifted");
}
const rootPackage = JSON.parse(
  await readFile(path.join(root, "package.json"), "utf8"),
);
for (const packageName of [
  "@capacitor/app",
  "@capacitor/core",
  "@capacitor/preferences",
  "@capacitor/android",
  "@capacitor/cli",
  "@capacitor/ios",
]) {
  if (
    rootPackage.dependencies?.[packageName] ||
    rootPackage.devDependencies?.[packageName]
  ) {
    violations.push(`duplicate-client dependency returned: ${packageName}`);
  }
}
const consumerWebPages = await filesUnder(
  path.join(root, "app"),
  (file) => file.endsWith(`${path.sep}page.tsx`),
);
if (consumerWebPages.length > 0) {
  violations.push(
    `consumer web pages returned to API-only backend: ${consumerWebPages.length}`,
  );
}
const pubspec = await readFile(path.join(mobile, "pubspec.yaml"), "utf8");
const lock = await readFile(path.join(mobile, "pubspec.lock"), "utf8");
const direct = pubspecDependencies(pubspec);
const permittedDirect = [...contract.permittedDirectFlutterDependencies].sort();
if (JSON.stringify(direct) !== JSON.stringify(permittedDirect)) {
  violations.push(
    `direct Flutter dependencies differ from allowlist: ${direct.join(", ")}`,
  );
}

for (const packageName of contract.prohibitedPackageNames) {
  const declaration = new RegExp(`^  ${packageName}:`, "m");
  if (declaration.test(pubspec)) {
    violations.push(`prohibited direct dependency: ${packageName}`);
  }
  if (declaration.test(lock)) {
    violations.push(`prohibited locked dependency: ${packageName}`);
  }
}

const dartFiles = await filesUnder(
  path.join(mobile, "lib"),
  (file) => file.endsWith(".dart"),
);
const dartSources = await Promise.all(
  dartFiles.map(async (file) => ({
    file: path.relative(root, file).replaceAll(path.sep, "/"),
    source: await readFile(file, "utf8"),
  })),
);
const allowedAnalyticsEvents = [...releaseContract.analytics.allowedV1Events].sort();
const catalogAnalyticsEvents = analyticsContract.events
  .map((event) => event.id)
  .sort();
if (
  JSON.stringify(allowedAnalyticsEvents) !==
  JSON.stringify(catalogAnalyticsEvents)
) {
  violations.push("V1 analytics event catalog differs from release contract");
}
for (const event of analyticsContract.events) {
  if (!/^[a-z][a-z0-9_]{1,39}$/.test(event.id)) {
    violations.push(`invalid analytics event id: ${event.id}`);
  }
  for (const property of event.properties) {
    if (!/^[a-z][a-z0-9_]{1,39}$/.test(property)) {
      violations.push(`invalid analytics property key: ${event.id}.${property}`);
    }
  }
}
for (const row of dartSources) {
  if (
    row.source.includes("package:firebase_analytics/") &&
    row.file !== releaseContract.analytics.facade
  ) {
    violations.push(`direct analytics provider import outside facade: ${row.file}`);
  }
  if (
    row.source.includes("ProductAnalytics.track(") &&
    !row.file.endsWith("_analytics.dart") &&
    row.file !== releaseContract.analytics.facade
  ) {
    violations.push(`direct analytics call outside typed facade: ${row.file}`);
  }
}
for (const packageName of contract.prohibitedPackageNames) {
  const importPattern = new RegExp(
    `(?:import|export)\\s+['"]package:${packageName}(?:/|['"])`,
  );
  for (const row of dartSources) {
    if (importPattern.test(row.source)) {
      violations.push(`prohibited package import in ${row.file}: ${packageName}`);
    }
  }
}

const antiFeatureGuard = productContract.antiFeatureGuard;
const prohibitedProductionDirectories = [
  ...antiFeatureGuard.prohibitedProductionFeatureDirectories.map(
    (name) => `${antiFeatureGuard.productionFeatureRoot}/${name}`,
  ),
  ...antiFeatureGuard.prohibitedProductionDirectories,
];
const legitimateProductionDirectories = new Set(
  antiFeatureGuard.legitimateProductionDirectories,
);
for (const directory of prohibitedProductionDirectories) {
  if (legitimateProductionDirectories.has(directory)) {
    violations.push(
      `capability guard configuration lists ${directory} as prohibited and legitimate`,
    );
  }
}
for (const row of dartSources) {
  const prohibitedDirectory = prohibitedProductionDirectories.find(
    (directory) =>
      row.file === directory || row.file.startsWith(`${directory}/`),
  );
  if (prohibitedDirectory) {
    violations.push(
      `prohibited production module remains: ${row.file} (${prohibitedDirectory})`,
    );
  }
}

const manifest = await readFile(
  path.join(mobile, "android/app/src/main/AndroidManifest.xml"),
  "utf8",
);
const activeTags = (tag) =>
  [...manifest.matchAll(new RegExp(`<${tag}\\b[^>]*>`, "g"))]
    .map((match) => match[0])
    .filter((value) => !/tools:node\s*=\s*["']remove["']/.test(value));
const activePermissions = unique(
  activeTags("uses-permission").flatMap(
    (tag) =>
      tag.match(
        /(?:android\.permission\.[A-Z0-9_.]+|com\.android\.vending\.BILLING)/g,
      ) ?? [],
  ),
);
if (
  JSON.stringify(activePermissions) !==
  JSON.stringify([...contract.permittedAndroidPermissions].sort())
) {
  violations.push(
    `active Android permissions differ from allowlist: ${activePermissions.join(", ")}`,
  );
}
for (const [tag, key] of [
  ["service", "permittedAndroidServices"],
  ["receiver", "permittedAndroidReceivers"],
  ["provider", "permittedAndroidProviders"],
]) {
  const names = unique(
    activeTags(tag)
      .map((value) => value.match(/android:name=["']([^"']+)/)?.[1])
      .filter(Boolean),
  );
  if (JSON.stringify(names) !== JSON.stringify([...contract[key]].sort())) {
    violations.push(`active Android ${tag}s differ from allowlist: ${names.join(", ")}`);
  }
}

const plist = await readFile(path.join(mobile, "ios/Runner/Info.plist"), "utf8");
const usageDescriptions = unique(
  plist.match(/NS[A-Za-z]+UsageDescription/g) ?? [],
);
if (
  JSON.stringify(usageDescriptions) !==
  JSON.stringify([...contract.permittedIosUsageDescriptions].sort())
) {
  violations.push(
    `iOS usage descriptions differ from allowlist: ${usageDescriptions.join(", ")}`,
  );
}
const forbiddenPlistKeys = [
  "NSBluetoothAlwaysUsageDescription",
  "NSCameraUsageDescription",
  "NSHealthShareUsageDescription",
  "NSHealthUpdateUsageDescription",
  "NSLocalNetworkUsageDescription",
  "NSLocationAlwaysAndWhenInUseUsageDescription",
  "NSLocationWhenInUseUsageDescription",
  "NSPhotoLibraryUsageDescription",
  "NSBonjourServices",
  "UIBackgroundModes",
];
for (const key of forbiddenPlistKeys) {
  if (plist.includes(`<key>${key}</key>`)) {
    violations.push(`prohibited iOS capability key: ${key}`);
  }
}

const releaseEntitlements = await readFile(
  path.join(mobile, "ios/Runner/Runner-Release.entitlements"),
  "utf8",
);
const entitlementKeys = unique(
  [...releaseEntitlements.matchAll(/<key>([^<]+)<\/key>/g)].map(
    (match) => match[1],
  ),
);
if (
  JSON.stringify(entitlementKeys) !==
  JSON.stringify([...contract.permittedIosEntitlements].sort())
) {
  violations.push(
    `iOS release entitlements differ from allowlist: ${entitlementKeys.join(", ")}`,
  );
}

const nativeChannelSources = await Promise.all([
  readFile(
    path.join(
      mobile,
      "android/app/src/main/kotlin/com/voicememory/mobile/MainActivity.kt",
    ),
    "utf8",
  ),
  readFile(path.join(mobile, "ios/Runner/AppDelegate.swift"), "utf8"),
]);
const channels = unique(
  [
    ...dartSources.map((row) => row.source),
    ...nativeChannelSources,
  ].flatMap((source) => [
    ...[...source.matchAll(/['"](archive_me\/[^'"]+)['"]/g)].map(
      (match) => match[1],
    ),
  ]),
);
if (
  JSON.stringify(channels) !==
  JSON.stringify([...contract.permittedPlatformChannels].sort())
) {
  violations.push(`platform channels differ from allowlist: ${channels.join(", ")}`);
}

if (violations.length) {
  console.error(violations.map((value) => `- ${value}`).join("\n"));
  process.exitCode = 1;
} else {
  console.log(
    `ArchiveMe V1 capability guard passed: ${direct.length} direct dependencies, ` +
      `${activePermissions.length} Android permissions, ${channels.length} platform channels.`,
  );
}
