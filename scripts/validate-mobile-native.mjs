#!/usr/bin/env node
/**
 * Validates Capacitor native scaffold — structure only, not store submission or device tests.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SPP20 =
  process.env.VOICEMEMORY_SPP20_DIR?.trim() ||
  path.resolve(ROOT, "..", "spp20");

const failures = [];
const warnings = [];

function mustExist(rel, label = rel) {
  const full = path.isAbsolute(rel) ? rel : path.join(ROOT, rel);
  if (!fs.existsSync(full)) failures.push(`missing ${label}`);
}

function mustInclude(file, needle, label) {
  const full = path.join(ROOT, file);
  const text = fs.readFileSync(full, "utf8");
  if (!text.includes(needle)) failures.push(`${file}: expected "${needle}" (${label})`);
}

function mustNotInclude(file, needle, label) {
  const full = path.join(ROOT, file);
  const text = fs.readFileSync(full, "utf8");
  if (text.includes(needle)) failures.push(`${file}: forbidden "${needle}" (${label})`);
}

const SPP20_DOCS = [
  "mobile_strategy_decision.md",
  "mobile_feature_parity_audit.md",
  "native_mobile_risk_audit.md",
  "app_store_readiness_checklist.md",
];

for (const doc of SPP20_DOCS) {
  const full = path.join(SPP20, doc);
  if (!fs.existsSync(full)) failures.push(`missing spp20 doc: ${doc}`);
}

mustExist("capacitor.config.ts");
mustExist("mobile/web/index.html");
mustExist("mobile/README.md");
mustExist("docs/MOBILE_NATIVE_SETUP.md");
mustExist("ios/App/App/Info.plist");
mustExist("android/app/src/main/AndroidManifest.xml");
mustExist("packages/shared/lib/mobile/deep-links.ts");
mustExist("packages/shared/lib/mobile/secure-storage.ts");
mustExist("packages/shared/lib/mobile/capacitor-bootstrap.ts");
mustExist("apps/web/components/mobile/NativeBootstrap.tsx");
mustExist("scripts/validate-mobile-native.mjs");

mustInclude("capacitor.config.ts", 'appId: "com.voicememory.app"', "app id");
mustInclude("capacitor.config.ts", 'appName: "ArchiveMe"', "app name");

mustInclude("ios/App/App/Info.plist", "NSMicrophoneUsageDescription", "iOS mic permission");
mustInclude("ios/App/App/Info.plist", "NSPhotoLibraryUsageDescription", "iOS photo permission");
mustInclude("ios/App/App/Info.plist", "voicememory", "iOS URL scheme");

mustInclude("android/app/src/main/AndroidManifest.xml", "RECORD_AUDIO", "Android mic");
mustInclude("android/app/src/main/AndroidManifest.xml", "voicememory", "Android deep link");

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
for (const script of [
  "mobile:init",
  "mobile:sync",
  "mobile:ios",
  "mobile:android",
  "validate:mobile-native",
]) {
  if (!pkg.scripts?.[script]) failures.push(`package.json missing script: ${script}`);
}

if (!pkg.dependencies?.["@capacitor/core"]) {
  failures.push("package.json missing @capacitor/core dependency");
}

mustInclude("packages/shared/lib/mobile/platform.ts", "capacitor", "platform runtime");
mustNotInclude(
  "packages/shared/lib/mobile/platform.ts",
  "if (isNativeWrapper()) return true",
  "no fake native push/audio",
);

const platform = fs.readFileSync(path.join(ROOT, "packages/shared/lib/mobile/platform.ts"), "utf8");
if (platform.includes("not wired yet")) {
  failures.push("platform.ts still claims Capacitor is not wired");
}

const dartFiles = [];
function walkDart(dir) {
  if (!fs.existsSync(dir)) return;
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory() && !["node_modules", ".git"].includes(ent.name)) walkDart(p);
    else if (ent.name.endsWith(".dart")) dartFiles.push(p);
  }
}
walkDart(ROOT);
if (dartFiles.length > 0) {
  failures.push(
    `Dart files present (${dartFiles.length}) but strategy is Capacitor — remove or document Flutter fork`,
  );
}

const mobileReadme = fs.readFileSync(path.join(ROOT, "mobile/README.md"), "utf8").toLowerCase();
for (const phrase of ["capacitor", "no flutter", "not native parity", "push"]) {
  if (!mobileReadme.includes(phrase)) {
    warnings.push(`mobile/README.md may not mention: ${phrase}`);
  }
}

if (!fs.existsSync(path.join(ROOT, "mobile/resources/README.md"))) {
  warnings.push("mobile/resources/README.md missing — add icon/splash placeholders doc");
}

if (failures.length > 0) {
  console.error("validate:mobile-native FAILED\n");
  for (const f of failures) console.error(`  ✗ ${f}`);
  if (warnings.length) {
    console.error("\nWarnings:");
    for (const w of warnings) console.error(`  ! ${w}`);
  }
  process.exit(1);
}

console.log("validate:mobile-native passed (Capacitor scaffold, docs, permissions, scripts).");
if (warnings.length) {
  console.log("Warnings:");
  for (const w of warnings) console.warn(`  ! ${w}`);
}
