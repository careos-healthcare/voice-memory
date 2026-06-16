#!/usr/bin/env node
/**
 * Archive Clarity & Momentum System v1 — at-a-glance archive, impact receipts, simplicity nav.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const required = [
  "components/archive/ArchiveHomeScore.tsx",
  "components/archive/ReflectionImpactReceipt.tsx",
  "components/archive/ArchiveProgressBar.tsx",
  "components/archive/ArchiveIdentityBar.tsx",
  "components/archive/WhyOpenArchiveToday.tsx",
  "components/archive/ArchiveReductionSections.tsx",
  "lib/product/simplicity-mode.ts",
  "lib/archive/archive-reduction-rules.ts",
  "lib/archive/reflection-impact-receipt.ts",
  "lib/archive/archive-home-score.ts",
  "lib/archive/archive-case-file-progress.ts",
  "lib/archive/why-open-archive-today.ts",
  "scripts/validate-archive-clarity-momentum.mjs",
];

for (const rel of required) mustExist(rel);

const archiveHome = read("components/archive/EvidenceArchiveHome.tsx");
for (const token of [
  "ArchiveHomeScore",
  "WhyOpenArchiveToday",
  "ArchiveIdentityBar",
  "ArchiveProgressBar",
]) {
  if (!archiveHome.includes(token)) fail(`EvidenceArchiveHome missing ${token}`);
}
const beliefHeaderIdx = archiveHome.indexOf("<ArchiveBeliefHeader");
const blueprintIdx = archiveHome.indexOf("<ArchivePageBlueprint");
if (beliefHeaderIdx < 0 || blueprintIdx < 0 || beliefHeaderIdx > blueprintIdx) {
  fail("ArchiveBeliefHeader must appear before ArchivePageBlueprint on archive home");
}

const recorder = read("components/Recorder.tsx");
if (!recorder.includes("ReflectionImpactReceipt")) {
  fail("Recorder must show ReflectionImpactReceipt after save");
}
if (recorder.includes("Reflection saved") && !recorder.includes("impactReceiptLabel")) {
  fail("Recorder must not use generic Reflection saved copy for complete state");
}
for (const banned of ["Reflection recorded", "Entry captured"]) {
  if (recorder.includes(banned)) fail(`Recorder must not say: ${banned}`);
}

const impact = read("lib/archive/reflection-impact-receipt.ts");
const successCopy = read("lib/design/archive-success-copy.ts");
if (!impact.includes("ARCHIVE_SUCCESS_HEADLINE") || !impact.includes("ARCHIVE_SUCCESS_BY_KIND")) {
  fail("reflection-impact-receipt must use archive-success-copy");
}
for (const label of [
  "New evidence supported this belief.",
  "New evidence challenged this belief.",
  "Archive confidence increased.",
]) {
  if (!successCopy.includes(label)) fail(`archive-success-copy missing: ${label}`);
}

const forbiddenIntel = ["openai", "generateTheory", "pattern-engine", "SemanticSearch", "llm"];
for (const file of [
  "lib/archive/archive-home-score.ts",
  "lib/archive/why-open-archive-today.ts",
  "lib/archive/reflection-impact-receipt.ts",
]) {
  const src = read(file);
  for (const token of forbiddenIntel) {
    if (src.includes(token)) fail(`${file} must not add new intelligence: ${token}`);
  }
}

const simplicity = read("lib/product/simplicity-mode.ts");
if (!simplicity.includes("VOICEMEMORY_ARCHIVE_POSITIONING")) {
  fail("simplicity-mode must re-export archive positioning");
}
for (const label of ["Record", "Archive", "Archive Activity", "Account"]) {
  if (!simplicity.includes(`label: "${label}"`)) fail(`simplicity primary nav missing ${label}`);
}
const primaryNavBlock = simplicity.slice(
  simplicity.indexOf("SIMPLICITY_PRIMARY_NAV"),
  simplicity.indexOf("ARCHIVE_DETAIL_ROUTES"),
);
if (primaryNavBlock.includes('label: "Search"')) {
  fail("Search must not be in SIMPLICITY_PRIMARY_NAV");
}

const header = read("components/SiteHeader.tsx");
if (!header.includes("SIMPLICITY_PRIMARY_NAV")) fail("SiteHeader must use SIMPLICITY_PRIMARY_NAV");
for (const demoted of ["/theories", "/blind-spots", "/insights"]) {
  if (header.includes(`href: "${demoted}"`)) {
    fail(`demoted route must not be in SiteHeader primary nav: ${demoted}`);
  }
}

const identityBar = read("components/archive/ArchiveIdentityBar.tsx");
if (!identityBar.includes("VOICEMEMORY_ARCHIVE_POSITIONING")) {
  fail("ArchiveIdentityBar must use canonical positioning");
}
if (!fs.existsSync(path.join(ROOT, "lib/product/archive-positioning.ts"))) {
  fail("missing lib/product/archive-positioning.ts");
}

const discoverPage = read("app/discover/page.tsx");
if (!discoverPage.includes("ArchiveBeliefHeader")) {
  fail("discover must render ArchiveBeliefHeader");
}
for (const page of ["app/account/page.tsx", "app/search/page.tsx", "app/page.tsx"]) {
  if (!read(page).includes("ArchiveIdentityBar")) {
    fail(`${page} must render ArchiveIdentityBar`);
  }
}

const productCopy = read("lib/product/archive-product-copy.ts");
if (!productCopy.includes("DISCOVER_PAGE_HEADING")) fail("discover product copy missing heading");
if (!productCopy.includes('"Archive Activity"')) {
  fail("Discover must be framed as Archive Activity");
}
if (!productCopy.includes("What changed since your last visit")) {
  fail("Discover subheadline must explain since last visit");
}

const commandCenter = read("components/archive/ArchiveCommandCenter.tsx");
if (!commandCenter.includes("WhyTheArchiveTrustsThis")) {
  fail("ArchiveCommandCenter must include WhyTheArchiveTrustsThis");
}
if (commandCenter.includes("ArchiveReductionSections")) {
  fail("ArchiveCommandCenter must not use ArchiveReductionSections (surface reduction v2)");
}
if (!read("lib/archive/archive-reduction-rules.ts").includes("Show more archive detail")) {
  fail("archive-reduction-rules must use Show more archive detail label");
}
if (!read("components/archive/EvidenceArchiveHome.tsx").includes("ArchiveDetailHub")) {
  fail("archive home must include ArchiveDetailHub");
}

const whyOpen = read("lib/archive/why-open-archive-today.ts");
for (const line of [
  "The archive became more certain.",
  "New evidence appeared.",
  "A belief was challenged.",
  "A pattern has not appeared recently.",
  "The archive changed its view.",
]) {
  if (!whyOpen.includes(line)) fail(`why-open-archive-today missing line: ${line}`);
}

const mobileShell = read("apps/voicememory_mobile/lib/widgets/main_shell.dart");
for (const label of ["Record", "Archive", "Changes", "Account"]) {
  if (!mobileShell.includes(`label: '${label}'`)) fail(`mobile nav missing ${label}`);
}
if (mobileShell.includes("Search") || mobileShell.includes("'Discover'")) {
  fail("mobile bottom nav must not include Search or Discover label");
}

const router = read("apps/voicememory_mobile/lib/router/app_router.dart");
if (!router.includes("archive-belief")) fail("mobile default must keep archive-belief route");

const returning = read("lib/product/returning-home.ts");
if (!returning.includes("/archive-belief")) fail("returning home must prefer archive-belief");

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:archive-clarity-momentum"]) {
  fail("package.json missing validate:archive-clarity-momentum script");
}

if (failures.length) {
  console.error("validate-archive-clarity-momentum failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-archive-clarity-momentum passed");
