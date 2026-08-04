#!/usr/bin/env node
// Release guard: asserts the shipping iOS and Android projects agree with the
// canonical identity recorded in config/release/archive_me_identity.json.
// Only source-verifiable fields are checked. Fields marked BLOCKED_EXTERNAL in
// the manifest are reported, never asserted.
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const IDENTITY_PATH = "config/release/archive_me_identity.json";
const CLIENT = "apps/voicememory_mobile";

const PBXPROJ = `${CLIENT}/ios/Runner.xcodeproj/project.pbxproj`;
const INFO_PLIST = `${CLIENT}/ios/Runner/Info.plist`;
const RUNNER_ENTITLEMENTS = `${CLIENT}/ios/Runner/Runner.entitlements`;
const GRADLE = `${CLIENT}/android/app/build.gradle.kts`;
const MANIFEST = `${CLIENT}/android/app/src/main/AndroidManifest.xml`;
const RELEASE_IDENTITY_DART = `${CLIENT}/lib/config/release_identity.dart`;

const identity = JSON.parse(await readFile(path.join(root, IDENTITY_PATH), "utf8"));
const iosBundleId = identity.ios?.bundleId;
const androidApplicationId = identity.android?.applicationId;

const failures = [];

if (!iosBundleId) failures.push(`${IDENTITY_PATH}: ios.bundleId is missing`);
if (!androidApplicationId) {
  failures.push(`${IDENTITY_PATH}: android.applicationId is missing`);
}
if (failures.length > 0) fail();

// --- iOS: the Runner target's Release build configuration is authoritative ---
const pbxproj = await read(PBXPROJ);
const declaredBundleIds = [
  ...pbxproj.matchAll(/PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/g),
].map((match) => match[1].trim().replace(/^"|"$/g, ""));

if (declaredBundleIds.length === 0) {
  failures.push(`${PBXPROJ}: no PRODUCT_BUNDLE_IDENTIFIER declarations found`);
}
if (!declaredBundleIds.includes(iosBundleId)) {
  failures.push(
    `${PBXPROJ}: canonical iOS bundle id ${iosBundleId} is not declared; found ${unique(declaredBundleIds).join(", ")}`,
  );
}

// Every declared bundle id must be the canonical id or a suffixed child target.
const expectedTargetIds = new Set(
  Object.values(identity.ios?.targetBundleIds ?? {}),
);
for (const declared of unique(declaredBundleIds)) {
  if (declared === iosBundleId) continue;
  if (!declared.startsWith(`${iosBundleId}.`)) {
    failures.push(
      `${PBXPROJ}: bundle id ${declared} is neither the canonical id ${iosBundleId} nor one of its sub-target ids`,
    );
    continue;
  }
  if (expectedTargetIds.size > 0 && !expectedTargetIds.has(declared)) {
    failures.push(
      `${PBXPROJ}: sub-target bundle id ${declared} is not recorded in ${IDENTITY_PATH} ios.targetBundleIds`,
    );
  }
}
for (const expected of expectedTargetIds) {
  if (!declaredBundleIds.includes(expected)) {
    failures.push(
      `${IDENTITY_PATH}: ios.targetBundleIds declares ${expected} but ${PBXPROJ} does not`,
    );
  }
}

// --- iOS Info.plist and entitlements ---
const infoPlist = await read(INFO_PLIST);
if (!infoPlist.includes("$(PRODUCT_BUNDLE_IDENTIFIER)")) {
  failures.push(
    `${INFO_PLIST}: CFBundleIdentifier should resolve from $(PRODUCT_BUNDLE_IDENTIFIER) so the plist cannot drift from the pbxproj`,
  );
}
const primaryScheme = identity.urlSchemes?.primary;
if (primaryScheme && !infoPlist.includes(`<string>${primaryScheme}</string>`)) {
  failures.push(
    `${INFO_PLIST}: canonical URL scheme ${primaryScheme} is not declared in CFBundleURLSchemes`,
  );
}

const entitlements = await read(RUNNER_ENTITLEMENTS);
const appGroupId = identity.ios?.appGroupId;
if (appGroupId && !entitlements.includes(appGroupId)) {
  failures.push(`${RUNNER_ENTITLEMENTS}: app group ${appGroupId} is not declared`);
}
const keychainGroup = identity.keychainAccessGroup?.value;
if (keychainGroup && !entitlements.includes(keychainGroup)) {
  failures.push(
    `${RUNNER_ENTITLEMENTS}: keychain access group ${keychainGroup} is not declared`,
  );
}
const icloudContainer = identity.ios?.iCloudContainerId;
if (icloudContainer && !entitlements.includes(icloudContainer)) {
  failures.push(
    `${RUNNER_ENTITLEMENTS}: iCloud container ${icloudContainer} is not declared`,
  );
}

// --- Android ---
const gradle = await read(GRADLE);
const declaredApplicationId = gradle.match(/applicationId\s*=\s*"([^"]+)"/)?.[1];
if (declaredApplicationId !== androidApplicationId) {
  failures.push(
    `${GRADLE}: applicationId is ${declaredApplicationId ?? "absent"}, expected ${androidApplicationId}`,
  );
}
const declaredNamespace = gradle.match(/namespace\s*=\s*"([^"]+)"/)?.[1];
const expectedNamespace = identity.android?.namespace ?? androidApplicationId;
if (declaredNamespace !== expectedNamespace) {
  failures.push(
    `${GRADLE}: namespace is ${declaredNamespace ?? "absent"}, expected ${expectedNamespace}`,
  );
}

const manifest = await read(MANIFEST);
if (primaryScheme && !manifest.includes(`android:scheme="${primaryScheme}"`)) {
  failures.push(
    `${MANIFEST}: canonical URL scheme ${primaryScheme} is not declared in an intent filter`,
  );
}

// --- Dart mirror used by the shipping client ---
const releaseIdentityDart = await read(RELEASE_IDENTITY_DART);
if (!releaseIdentityDart.includes(`'${iosBundleId}'`)) {
  failures.push(
    `${RELEASE_IDENTITY_DART}: ReleaseIdentity.applicationId does not equal ${iosBundleId}`,
  );
}

// --- No neutralised experimental identifier may leak into shipping config ---
const shippingSurfaces = [
  [PBXPROJ, pbxproj],
  [INFO_PLIST, infoPlist],
  [RUNNER_ENTITLEMENTS, entitlements],
  [GRADLE, gradle],
  [MANIFEST, manifest],
  [RELEASE_IDENTITY_DART, releaseIdentityDart],
];
const forbidden = unique([
  ...(identity.experimentalIdentifiers ?? [])
    .map((entry) => entry.value)
    .filter((value) => typeof value === "string" && value.includes(".")),
  ...(identity.legacyIdentifiers ?? [])
    .filter((entry) => entry.classification === "legacy migration compatibility")
    .map((entry) => entry.value)
    .filter((value) => typeof value === "string" && value.includes(".")),
]).filter((value) => value !== iosBundleId && value !== androidApplicationId);

for (const [file, source] of shippingSurfaces) {
  for (const value of forbidden) {
    if (source.includes(value)) {
      failures.push(
        `${file}: contains neutralised identifier ${value}, which must never appear in shipping release configuration`,
      );
    }
  }
}

// --- Store product ids must not be confused with bundle ids ---
const productIds = unique([
  ...(identity.storeProductIds?.ios ?? []),
  ...(identity.storeProductIds?.android ?? []),
]);
for (const productId of productIds) {
  if (productId === iosBundleId || productId === androidApplicationId) {
    failures.push(
      `${IDENTITY_PATH}: store product id ${productId} is identical to a bundle identifier; these are different namespaces and must never be conflated`,
    );
  }
  if (declaredBundleIds.includes(productId)) {
    failures.push(
      `${PBXPROJ}: store product id ${productId} is declared as a bundle identifier`,
    );
  }
}

if (failures.length > 0) fail();

const blocked = identity.verification?.blockedExternal ?? [];
console.log(
  `release identity ok: iOS bundle id ${iosBundleId}, Android application id ${androidApplicationId}; ` +
    `${unique(declaredBundleIds).length} iOS target id(s) verified, ${productIds.length} store product id(s) kept distinct from bundle ids`,
);
console.log(
  `release identity gate: BLOCKED_EXTERNAL — ${blocked.length} field(s) cannot be verified from source ` +
    `(${unique(blocked.map((entry) => entry.system)).join(", ")}). See ${identity.verification?.manualChecklist}.`,
);

function unique(values) {
  return [...new Set(values)];
}

async function read(relativePath) {
  try {
    return await readFile(path.join(root, relativePath), "utf8");
  } catch {
    failures.push(`missing required file: ${relativePath}`);
    fail();
  }
}

function fail() {
  console.error(`release identity guard FAILED (${failures.length} problem(s)):`);
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}
