#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const required = [
  "lib/continuity/first-return-moment.ts",
  "components/continuity/FirstReturnMoment.tsx",
  "components/journal/JournalArchiveRow.tsx",
  "lib/product/recognition-copy.ts",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const home = fs.readFileSync(path.join(ROOT, "app/page.tsx"), "utf8");
if (!home.includes("FirstReturnMoment")) {
  failures.push("homepage must render FirstReturnMoment");
}
if (!home.includes("desktopRecognitionCenter")) {
  failures.push("homepage must center desktop on first return moment");
}
if (!home.includes("presentation=\"quiet\"")) {
  failures.push("homepage must use quiet first-return presentation");
}

if (!fs.existsSync(path.join(ROOT, "lib/continuity/first-return-observation.ts"))) {
  failures.push("missing first-return-observation metrics");
}
const observation = fs.readFileSync(
  path.join(ROOT, "lib/continuity/first-return-observation.ts"),
  "utf8",
);
for (const token of [
  "firstReturnShownAt",
  "firstReturnOpenedAt",
  "rerecordWithin10MinAt",
  "recordFirstReturnShown",
  "recordFirstReturnOpened",
  "maybeRecordFirstReturnRerecordWithin10Min",
]) {
  if (!observation.includes(token)) failures.push(`first-return metrics missing ${token}`);
}

const journal = fs.readFileSync(path.join(ROOT, "app/journal/page.tsx"), "utf8");
if (!journal.includes("FirstReturnMoment")) {
  failures.push("journal must render FirstReturnMoment");
}
if (!journal.includes("JournalArchiveRow")) {
  failures.push("journal must use light JournalArchiveRow");
}
if (journal.includes("line-clamp-2")) {
  failures.push("journal must not use heavy line-clamp-2 transcript previews");
}
if (journal.includes("HabitLoopCard")) {
  failures.push("journal must not lead with habit/rhythm cards");
}

const launch = fs.readFileSync(path.join(ROOT, "app/launch/page.tsx"), "utf8");
if (launch.includes('href="/debug')) {
  failures.push("launch must not link to debug routes");
}

const siteHeader = fs.readFileSync(path.join(ROOT, "components/SiteHeader.tsx"), "utf8");
if (siteHeader.includes("/debug")) {
  failures.push("SiteHeader must not link to debug");
}

const bannedVoice = fs.readFileSync(path.join(ROOT, "lib/product/recognition-copy.ts"), "utf8");
const bannedList = bannedVoice.match(/BANNED_PRODUCT_VOICE = \[([\s\S]*?)\]/)?.[1] ?? "";
for (const line of bannedList.split("\n")) {
  const m = line.match(/"([^"]+)"/);
  if (!m) continue;
  const phrase = m[1].toLowerCase();
  for (const rel of ["app/journal/page.tsx", "app/memory/page.tsx", "app/page.tsx"]) {
    const src = fs.readFileSync(path.join(ROOT, rel), "utf8").toLowerCase();
    if (src.includes(phrase)) failures.push(`${rel} contains banned phrase: ${phrase}`);
  }
}

const copy = fs.readFileSync(path.join(ROOT, "lib/product-copy.ts"), "utf8");
if (copy.includes("VoiceMemory brings back")) {
  failures.push("product-copy must not use abstract brings-back framing");
}
if (!copy.includes("You said this before") && !copy.includes("RECOGNITION_COPY.wedge")) {
  failures.push("product-copy must use recognition wedge");
}

const mod = await import(pathToFileURL(path.join(ROOT, "lib/continuity/first-return-moment.ts")).href);

const junk = mod.pickFirstReturnMoment([
  {
    id: "1",
    createdAt: "2026-01-01T12:00:00.000Z",
    transcript: "thank you for watching",
    durationSeconds: 10,
    reflection: {
      mood: "n",
      emotionalIntensity: 5,
      recurringThemes: [],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    },
  },
  {
    id: "2",
    createdAt: "2026-01-02T12:00:00.000Z",
    transcript: "test test test",
    durationSeconds: 10,
    reflection: {
      mood: "n",
      emotionalIntensity: 5,
      recurringThemes: [],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    },
  },
]);
if (junk !== null) failures.push("first return moment must not surface junk");

if (failures.length > 0) {
  console.error("validate-first-return-moment failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-first-return-moment ok");
