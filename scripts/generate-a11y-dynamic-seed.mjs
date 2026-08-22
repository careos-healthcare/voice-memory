#!/usr/bin/env node
/**
 * Generates deterministic E2E seed data + dynamic route URLs for a11y tests.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

import { buildConversationThreadsReport } from "../packages/shared/lib/memory/conversation-threads.ts";
import { buildEmotionalTerritoriesReport } from "../packages/shared/lib/territories/emotional-territories.ts";
import { buildWeeklyPeriod, buildMonthlyPeriod } from "../packages/shared/lib/roundups/reflective-roundups.ts";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const ANCHOR_END = "2026-05-20";

function reflection() {
  return {
    mood: "steady",
    emotionalIntensity: 5,
    recurringThemes: ["Work stress"],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
    concreteObservation: "Work and meetings kept returning in your words.",
    exactLanguagePattern: "the project and my manager",
  };
}

function makeEntry(index, dayKey) {
  const id = `a11y-seed-${String(index).padStart(3, "0")}`;
  return {
    id,
    createdAt: `${dayKey}T14:00:00.000Z`,
    transcript:
      "Today at work I thought about the project and my manager. The meeting felt heavy but I named what I will do next.",
    reflection: reflection(),
    durationSeconds: 42,
    reflectionPending: false,
  };
}

const entries = [];
for (let i = 0; i < 14; i += 1) {
  const day = `2026-05-${String(i + 1).padStart(2, "0")}`;
  entries.push(makeEntry(i + 1, day));
}

const threads = buildConversationThreadsReport(entries);
const territories = buildEmotionalTerritoriesReport(entries);
const weekPeriod = buildWeeklyPeriod(ANCHOR_END);
const monthPeriod = buildMonthlyPeriod("2026-05");

const threadSlug =
  threads.threads.find((t) => t.title === "Work stress")?.slug ?? threads.threads[0]?.slug;
const territorySlug =
  territories.territories.find((t) => t.defaultLabel === "Around work")?.slug ??
  territories.territories[0]?.slug;

if (!threadSlug || !territorySlug) {
  console.error("Failed to derive thread/territory slugs from seed data");
  process.exit(1);
}

const routes = [
  {
    pattern: "/entry/[id]",
    path: `/entry/${entries[0].id}`,
    sampleUrls: [`/entry/${entries[0].id}`],
    seed: "a11y-seed-001 in voicememory_entries",
    needsRealUserData: false,
    risk: "Large client surface; motion and icon-only controls",
    strategy: "Seed localStorage + axe + landmarks",
  },
  {
    pattern: "/threads/[slug]",
    path: `/threads/${threadSlug}`,
    sampleUrls: [`/threads/${threadSlug}`],
    seed: `14 entries + theme Work stress → slug ${threadSlug}`,
    needsRealUserData: false,
    risk: "Icon back link; zinc-500 body copy",
    strategy: "Seed + resolved slug from fixture generator",
  },
  {
    pattern: "/territories/[slug]",
    path: `/territories/${territorySlug}`,
    sampleUrls: [`/territories/${territorySlug}`],
    seed: `work transcripts → slug ${territorySlug}`,
    needsRealUserData: false,
    risk: "Missing main landmark on detail page",
    strategy: "Seed + territory slug from generator",
  },
  {
    pattern: "/roundups/[period]",
    path: `/roundups/${weekPeriod.slug}`,
    sampleUrls: [
      `/roundups/${weekPeriod.slug}`,
      `/roundups/${monthPeriod.slug}`,
      "/roundups/week",
    ],
    seed: `entries in ${weekPeriod.startDayKey}…${weekPeriod.endDayKey}; Date frozen to ${ANCHOR_END} in E2E`,
    needsRealUserData: false,
    risk: "Framer header opacity",
    strategy: "Seed + frozen clock in Playwright init",
  },
];

const fixtureDir = resolve(ROOT, "e2e/fixtures");
mkdirSync(fixtureDir, { recursive: true });
writeFileSync(
  resolve(fixtureDir, "a11y-dynamic-seed.json"),
  JSON.stringify(
    {
      anchorEndDayKey: ANCHOR_END,
      storageKey: "voicememory_entries",
      storageVersionKey: "voicememory_storage_version",
      storageVersion: 1,
      entries,
      routes: routes.map((r) => r.path),
      threadSlug,
      territorySlug,
      weekPeriodSlug: weekPeriod.slug,
      monthPeriodSlug: monthPeriod.slug,
      primaryEntryId: entries[0].id,
    },
    null,
    2,
  ),
);

const md = `# Dynamic route accessibility inventory

**Generated:** ${new Date().toISOString().slice(0, 19)}Z

Synthetic fixture only — no production user content.

| Route pattern | Sample URL | Seed data | Real user data? | Risk | Test strategy |
|---------------|------------|-----------|-----------------|------|---------------|
${routes
  .map(
    (r) =>
      `| \`${r.pattern}\` | \`${r.path}\` | ${r.seed} | No | ${r.risk} | ${r.strategy} |`,
  )
  .join("\n")}

## E2E coverage

- Spec: \`e2e/ui-a11y-dynamic.spec.ts\`
- Command: \`npm run test:a11y:dynamic\`
- Fixture: \`e2e/fixtures/a11y-dynamic-seed.json\` (regenerate via \`node scripts/generate-a11y-dynamic-seed.mjs\`)

## Excluded dynamic routes

| Route | Reason |
|-------|--------|
| \`/internal/*\` | Tier D — locked 404 only (see \`ui-a11y-full.spec.ts\`) |
| \`/launch\`, \`/demo\`, etc. | Non-public launch surface |

## Not-found states (accessible)

| URL | Expected |
|-----|----------|
| \`/entry/a11y-missing-entry\` | h1 + calm copy |
| \`/threads/a11y-missing-thread\` | h1 Thread not found |
| \`/territories/a11y-missing-territory\` | h1 + back link |
`;

writeFileSync(
  resolve(process.env.HOME ?? "/Users/chiragpatel", "Desktop/spp20/dynamic_route_accessibility_inventory.md"),
  md,
);

console.log("Wrote e2e/fixtures/a11y-dynamic-seed.json");
console.log("Wrote spp20/dynamic_route_accessibility_inventory.md");
console.log("Routes:", routes.map((r) => r.path).join(", "));
