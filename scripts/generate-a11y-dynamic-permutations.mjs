#!/usr/bin/env node
/**
 * Deterministic accessibility content permutations for dynamic routes.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

import { buildConversationThreadsReport } from "../packages/shared/lib/memory/conversation-threads.ts";
import { buildEmotionalTerritoriesReport } from "../packages/shared/lib/territories/emotional-territories.ts";
import { buildWeeklyPeriod } from "../packages/shared/lib/roundups/reflective-roundups.ts";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const ANCHOR_END = "2026-05-20";

function baseReflection(overrides = {}) {
  return {
    mood: "steady",
    emotionalIntensity: 5,
    recurringThemes: ["Work stress"],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
    concreteObservation: "Work and meetings kept returning.",
    exactLanguagePattern: "the project and my manager",
    ...overrides,
  };
}

function fillerEntries(count, startIndex) {
  const out = [];
  for (let i = 0; i < count; i += 1) {
    const n = startIndex + i;
    const day = `2026-05-${String((n % 14) + 1).padStart(2, "0")}`;
    out.push({
      id: `a11y-perm-filler-${String(n).padStart(3, "0")}`,
      createdAt: `${day}T10:00:00.000Z`,
      transcript:
        "At work with Alex and Sam I discussed the project and my manager in a meeting about deadlines.",
      reflection: baseReflection({ recurringThemes: ["Work stress", "Deadlines"] }),
      durationSeconds: 30,
      reflectionPending: false,
    });
  }
  return out;
}

function buildArchive(hero) {
  return [...fillerEntries(13, 1), hero].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function routesForEntries(entries) {
  const threads = buildConversationThreadsReport(entries);
  const territories = buildEmotionalTerritoriesReport(entries);
  const week = buildWeeklyPeriod(ANCHOR_END);
  const hero = entries[entries.length - 1];
  const thread = threads.threads[0];
  const territory = territories.territories.find((t) => t.kind === "work") ?? territories.territories[0];
  return {
    entry: `/entry/${hero.id}`,
    thread: thread ? `/threads/${thread.slug}` : null,
    territory: territory ? `/territories/${territory.slug}` : null,
    roundupWeek: `/roundups/${week.slug}`,
  };
}

const CASES = [
  {
    id: "very-short",
    hero: {
      id: "a11y-perm-short",
      createdAt: "2026-05-10T12:00:00.000Z",
      transcript: "Ok.",
      reflection: baseReflection({ concreteObservation: "Brief.", exactLanguagePattern: "Ok." }),
      durationSeconds: 3,
    },
  },
  {
    id: "very-long",
    hero: {
      id: "a11y-perm-long",
      createdAt: "2026-05-11T12:00:00.000Z",
      transcript: `${"I keep thinking about work and my manager. ".repeat(80)}The project deadline will not leave my head.`,
      reflection: baseReflection({
        concreteObservation: "A long span of worry about work.",
        emotionalIntensity: 7,
      }),
      durationSeconds: 600,
    },
  },
  {
    id: "empty-optional-fields",
    hero: {
      id: "a11y-perm-empty-opt",
      createdAt: "2026-05-12T12:00:00.000Z",
      transcript: "Work meeting with my manager about the project.",
      reflection: baseReflection({
        exactLanguagePattern: undefined,
        concreteObservation: undefined,
        repeatedSignal: undefined,
        patternObservations: undefined,
      }),
      durationSeconds: 20,
    },
  },
  {
    id: "long-unbroken-token",
    hero: {
      id: "a11y-perm-url",
      createdAt: "2026-05-13T12:00:00.000Z",
      transcript:
        "See https://example.com/very/long/path/without/breaks/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa and my manager at work.",
      reflection: baseReflection(),
      durationSeconds: 25,
    },
  },
  {
    id: "quotes",
    hero: {
      id: "a11y-perm-quotes",
      createdAt: "2026-05-14T12:00:00.000Z",
      transcript: 'My manager said "not yet" and I replied, "I hear you." Work on the project continues.',
      reflection: baseReflection({ exactLanguagePattern: '"not yet"' }),
      durationSeconds: 28,
    },
  },
  {
    id: "emoji",
    hero: {
      id: "a11y-perm-emoji",
      createdAt: "2026-05-15T12:00:00.000Z",
      transcript: "Heavy day at work 😮‍💨 — manager and project still on my mind ✨",
      reflection: baseReflection({ mood: "heavy" }),
      durationSeconds: 22,
    },
  },
  {
    id: "high-intensity",
    hero: {
      id: "a11y-perm-high",
      createdAt: "2026-05-16T12:00:00.000Z",
      transcript: "I am completely overwhelmed at work. My manager and the project feel unbearable today.",
      reflection: baseReflection({ emotionalIntensity: 10, mood: "overwhelmed" }),
      durationSeconds: 35,
    },
  },
  {
    id: "low-intensity",
    hero: {
      id: "a11y-perm-low",
      createdAt: "2026-05-17T12:00:00.000Z",
      transcript: "Quiet note: work was fine. Manager mentioned the project briefly.",
      reflection: baseReflection({ emotionalIntensity: 1, mood: "quiet" }),
      durationSeconds: 12,
    },
  },
  {
    id: "minimal-reflection",
    hero: {
      id: "a11y-perm-min-refl",
      createdAt: "2026-05-18T12:00:00.000Z",
      transcript: "Work project manager meeting.",
      reflection: {
        mood: "steady",
        emotionalIntensity: 5,
        recurringThemes: [],
        hiddenConcern: "",
        positiveSignal: "",
        recommendation: "",
      },
      durationSeconds: 15,
    },
  },
  {
    id: "repeated-phrases",
    hero: {
      id: "a11y-perm-repeat",
      createdAt: "2026-05-19T12:00:00.000Z",
      transcript:
        "My manager. My manager. The project. The project. Work. Work. I said my manager again about the project at work.",
      reflection: baseReflection({ repeatedSignal: "You named your manager repeatedly." }),
      durationSeconds: 40,
    },
  },
  {
    id: "multiple-speakers",
    hero: {
      id: "a11y-perm-speakers",
      createdAt: "2026-05-20T12:00:00.000Z",
      transcript:
        "Alex said one thing, Sam said another, and my manager closed the work meeting about the project.",
      reflection: baseReflection({ recurringThemes: ["Work stress", "Alex", "Sam"] }),
      durationSeconds: 38,
    },
  },
  {
    id: "no-transcript-pending",
    hero: {
      id: "a11y-perm-pending",
      createdAt: "2026-05-20T13:00:00.000Z",
      transcript: "",
      reflection: baseReflection(),
      durationSeconds: 5,
      reflectionPending: true,
    },
  },
  {
    id: "very-old-date",
    hero: {
      id: "a11y-perm-old",
      createdAt: "2019-03-01T12:00:00.000Z",
      transcript: "Old memory: work, manager, and the project felt distant then.",
      reflection: baseReflection(),
      durationSeconds: 18,
    },
  },
  {
    id: "future-date-guarded",
    hero: {
      id: "a11y-perm-future",
      createdAt: "2031-01-15T12:00:00.000Z",
      transcript: "If this date is odd, work and my manager still parse for layout tests.",
      reflection: baseReflection(),
      durationSeconds: 16,
    },
  },
  {
    id: "tolerant-extra-fields",
    hero: {
      id: "a11y-perm-extra",
      createdAt: "2026-05-20T14:00:00.000Z",
      transcript: "Work with manager on project — extra metadata tolerated.",
      reflection: baseReflection(),
      durationSeconds: 20,
      _legacyUnknownField: "stripped by normalize on load",
      extraClientOnly: true,
    },
  },
];

const permutations = CASES.map((c) => {
  const hero = { reflectionPending: false, ...c.hero };
  const entries = buildArchive(hero);
  const routes = routesForEntries(entries);
  return {
    id: c.id,
    label: c.id,
    entries,
    routes,
    testPaths: [
      routes.entry,
      routes.thread,
      routes.territory,
      routes.roundupWeek,
    ].filter(Boolean),
  };
});

const fixtureDir = resolve(ROOT, "e2e/fixtures");
mkdirSync(fixtureDir, { recursive: true });
writeFileSync(
  resolve(fixtureDir, "a11y-dynamic-permutations.json"),
  JSON.stringify(
    {
      anchorEndDayKey: ANCHOR_END,
      storageKey: "voicememory_entries",
      storageVersionKey: "voicememory_storage_version",
      storageVersion: 1,
      permutations,
    },
    null,
    2,
  ),
);

const md = `# Dynamic permutation accessibility coverage

**Generated:** ${new Date().toISOString().slice(0, 19)}Z

**Cases:** ${permutations.length} deterministic content profiles (synthetic only).

Each case seeds 14 local entries and tests up to 4 dynamic routes:

| Case | Entry route | Also tests |
|------|-------------|------------|
${permutations
  .map(
    (p) =>
      `| ${p.id} | \`${p.routes.entry}\` | ${[p.routes.thread, p.routes.territory, p.routes.roundupWeek].filter(Boolean).map((r) => `\`${r}\``).join(", ") || "—"} |`,
  )
  .join("\n")}

**Not claimed:** every infinite content permutation — broader deterministic coverage only.

**Regenerate:** \`npm run generate:a11y-dynamic-permutations\`
`;

writeFileSync(
  resolve(process.env.HOME ?? "/Users/chiragpatel", "Desktop/spp20/dynamic_permutation_a11y_report.md"),
  md,
);

console.log(`Wrote ${permutations.length} permutations to e2e/fixtures/a11y-dynamic-permutations.json`);
