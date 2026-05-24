import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import { formatEntryDate } from "@/lib/utils";
import { resolveTerritoryLabel } from "@/lib/territories/territory-preferences";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  EmotionalTerritoriesReport,
  EmotionalTerritory,
  EmotionalTerritoryEvolution,
  EmotionalTerritoryKind,
  EmotionalTerritoryReflection,
} from "@/types/emotional-territory";
import type { JournalEntry } from "@/types/journal";

const MIN_TERRITORY_ENTRIES = 2;
const GAP_DAYS = 10;
const MAX_RELATED_REFLECTIONS = 8;

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|eventually|vague)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|clearly|for sure|definitely)\b/gi;

interface PresetTerritory {
  id: EmotionalTerritoryKind;
  defaultLabel: string;
  patterns: RegExp[];
}

const PRESET_TERRITORIES: PresetTerritory[] = [
  {
    id: "work",
    defaultLabel: "Around work",
    patterns: [
      /\bwork\b/i,
      /\bjob\b/i,
      /\boffice\b/i,
      /\bboss\b/i,
      /\bmanager\b/i,
      /\bcolleague\b/i,
      /\bcoworker\b/i,
      /\bmeeting\b/i,
      /\bproject\b/i,
      /\bdeadline\b/i,
      /\bcareer\b/i,
      /\bcommute\b/i,
    ],
  },
  {
    id: "family",
    defaultLabel: "Around family",
    patterns: [
      /\bfamily\b/i,
      /\bparent\b/i,
      /\bparents\b/i,
      /\bmom\b/i,
      /\bmother\b/i,
      /\bmum\b/i,
      /\bdad\b/i,
      /\bfather\b/i,
      /\bsibling\b/i,
      /\bbrother\b/i,
      /\bsister\b/i,
      /\bkids\b/i,
      /\bchildren\b/i,
      /\bgrandma\b/i,
      /\bgrandpa\b/i,
    ],
  },
  {
    id: "relationships",
    defaultLabel: "Around relationships",
    patterns: [
      /\bpartner\b/i,
      /\brelationship\b/i,
      /\bmarriage\b/i,
      /\bdating\b/i,
      /\bboyfriend\b/i,
      /\bgirlfriend\b/i,
      /\bhusband\b/i,
      /\bwife\b/i,
      /\bspouse\b/i,
      /\bbreakup\b/i,
      /\bromantic\b/i,
      /\bwe are\b/i,
      /\bwe're\b/i,
    ],
  },
  {
    id: "money",
    defaultLabel: "About money",
    patterns: [
      /\bmoney\b/i,
      /\bfinance\b/i,
      /\bdebt\b/i,
      /\bsalary\b/i,
      /\brent\b/i,
      /\bmortgage\b/i,
      /\bsavings\b/i,
      /\bbills\b/i,
      /\bafford\b/i,
      /\bincome\b/i,
      /\bbudget\b/i,
      /\bpay\b/i,
      /\bcost\b/i,
    ],
  },
  {
    id: "home",
    defaultLabel: "Around home",
    patterns: [
      /\bhome\b/i,
      /\bhouse\b/i,
      /\bapartment\b/i,
      /\bmoving\b/i,
      /\brenovat/i,
      /\blandlord\b/i,
      /\broommate\b/i,
      /\bkitchen\b/i,
      /\bbedroom\b/i,
      /\bneighborhood\b/i,
    ],
  },
  {
    id: "health",
    defaultLabel: "Around health",
    patterns: [
      /\bhealth\b/i,
      /\bdoctor\b/i,
      /\btherapy\b/i,
      /\bsleep\b/i,
      /\bexercise\b/i,
      /\bpain\b/i,
      /\bsick\b/i,
      /\bmedication\b/i,
      /\bbody\b/i,
      /\benergy\b/i,
    ],
  },
  {
    id: "grief",
    defaultLabel: "Around grief",
    patterns: [
      /\bgrief\b/i,
      /\bgrieving\b/i,
      /\bloss\b/i,
      /\blost\b/i,
      /\bdied\b/i,
      /\bdeath\b/i,
      /\bfuneral\b/i,
      /\bmiss them\b/i,
      /\bmiss him\b/i,
      /\bmiss her\b/i,
      /\bpassed away\b/i,
    ],
  },
  {
    id: "identity",
    defaultLabel: "Around identity",
    patterns: [
      /\bwho i am\b/i,
      /\bidentity\b/i,
      /\bbecoming\b/i,
      /\bmyself\b/i,
      /\bself-worth\b/i,
      /\bauthentic\b/i,
      /\bbelong\b/i,
      /\bversion of me\b/i,
    ],
  },
  {
    id: "decisions",
    defaultLabel: "Around decisions",
    patterns: [
      /\bdecid/i,
      /\bchoice\b/i,
      /\bwhether to\b/i,
      /\bshould i\b/i,
      /\bcrossroads\b/i,
      /\boption\b/i,
      /\bwhat if i\b/i,
      /\bturning point\b/i,
    ],
  },
  {
    id: "rest",
    defaultLabel: "Around rest",
    patterns: [
      /\brest\b/i,
      /\btired\b/i,
      /\bexhaust/i,
      /\bburnout\b/i,
      /\bslow down\b/i,
      /\bpause\b/i,
      /\bvacation\b/i,
      /\bweekend\b/i,
      /\brecover\b/i,
      /\boverwhelmed\b/i,
    ],
  },
];

const RELATIONSHIP_ABOUT: Record<string, string> = {
  mom: "About Mum",
  mother: "About Mum",
  mum: "About Mum",
  dad: "About Dad",
  father: "About Dad",
  partner: "About your partner",
  wife: "About your wife",
  husband: "About your husband",
  spouse: "About your spouse",
  boss: "About your boss",
  manager: "About your manager",
  friend: "About your friend",
  friends: "About your friends",
  therapist: "About your therapist",
  doctor: "About your doctor",
  sister: "About your sister",
  brother: "About your brother",
  son: "About your son",
  daughter: "About your daughter",
  kids: "About your kids",
  child: "About your child",
  children: "About your children",
  colleague: "About your colleague",
  coworker: "About your coworker",
  team: "About your team",
  parent: "About your parent",
  parents: "About your parents",
};

interface RawTerritory {
  id: string;
  defaultLabel: string;
  kind: EmotionalTerritoryKind;
  entries: JournalEntry[];
  priority: number;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function entryText(entry: JournalEntry): string {
  return [
    entry.transcript,
    entry.reflection.mood,
    ...entry.reflection.recurringThemes,
    entry.reflection.exactLanguagePattern,
    entry.reflection.concreteObservation,
    entry.reflection.repeatedSignal,
    entry.reflection.hiddenConcern,
    entry.reflection.tensionOrContradiction,
    entry.reflection.avoidedOrVagueArea,
  ]
    .filter(Boolean)
    .join(" ");
}

function snippet(entry: JournalEntry): string {
  const fromReflection =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim();
  if (fromReflection) return fromReflection.slice(0, 160);
  return entry.transcript.trim().slice(0, 160);
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function textKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 72);
}

function toSlug(label: string): string {
  const base = label
    .toLowerCase()
    .replace(/^about\s+/i, "")
    .replace(/^around\s+/i, "")
    .replace(/[^\w\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 56);
  return base || "territory";
}

function formatShortDate(iso: string): string {
  const [y, m, d] = toDayKey(iso).split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: y !== new Date().getFullYear() ? "numeric" : undefined,
  }).format(new Date(y, m - 1, d));
}

function matchesPreset(entry: JournalEntry, preset: PresetTerritory): boolean {
  const text = entryText(entry);
  return preset.patterns.some((pattern) => pattern.test(text));
}

function addToMap(
  map: Map<string, RawTerritory>,
  id: string,
  defaultLabel: string,
  kind: EmotionalTerritoryKind,
  entry: JournalEntry,
  priority: number,
): void {
  let row = map.get(id);
  if (!row) {
    row = { id, defaultLabel, kind, entries: [], priority };
    map.set(id, row);
  }
  if (!row.entries.some((e) => e.id === entry.id)) {
    row.entries.push(entry);
  }
  row.priority = Math.max(row.priority, priority);
}

function buildPresetTerritories(sorted: JournalEntry[]): RawTerritory[] {
  const map = new Map<string, RawTerritory>();

  for (const entry of sorted) {
    for (const preset of PRESET_TERRITORIES) {
      if (!matchesPreset(entry, preset)) continue;
      addToMap(map, preset.id, preset.defaultLabel, preset.id, entry, 70);
    }
  }

  return [...map.values()].filter((row) => row.entries.length >= MIN_TERRITORY_ENTRIES);
}

function buildPersonTerritories(sorted: JournalEntry[]): RawTerritory[] {
  const snapshot = buildEntityMemoryFromEntries(sorted);
  const raw: RawTerritory[] = [];

  for (const person of snapshot.people) {
    if (person.entryIds.length < MIN_TERRITORY_ENTRIES) continue;
    const key = person.name.toLowerCase();
    const aboutLabel =
      RELATIONSHIP_ABOUT[key] ?? `About ${person.name.charAt(0).toUpperCase()}${person.name.slice(1)}`;
    const entries = sorted.filter((e) => person.entryIds.includes(e.id));
    raw.push({
      id: `person:${textKey(person.name)}`,
      defaultLabel: aboutLabel,
      kind: "person",
      entries,
      priority: 68 + person.mentionCount,
    });
  }

  return raw;
}

function buildTopicTerritories(sorted: JournalEntry[]): RawTerritory[] {
  const map = new Map<string, RawTerritory>();
  const presetKeys = new Set(PRESET_TERRITORIES.map((preset) => preset.id));

  for (const entry of sorted) {
    for (const theme of entry.reflection.recurringThemes) {
      const trimmed = theme.trim();
      if (trimmed.length < 3) continue;
      const normalized = trimmed.toLowerCase();
      if (presetKeys.has(normalized as EmotionalTerritoryKind)) continue;
      if (PRESET_TERRITORIES.some((preset) => preset.patterns.some((re) => re.test(trimmed)))) {
        continue;
      }

      const id = `topic:${textKey(trimmed)}`;
      const defaultLabel = `About ${trimmed.charAt(0).toUpperCase()}${trimmed.slice(1)}`;
      addToMap(map, id, defaultLabel, "topic", entry, 66);
    }
  }

  return [...map.values()].filter((row) => row.entries.length >= MIN_TERRITORY_ENTRIES);
}

function entryOverlap(a: JournalEntry[], b: JournalEntry[]): number {
  const setB = new Set(b.map((e) => e.id));
  const shared = a.filter((e) => setB.has(e.id)).length;
  return shared / Math.min(a.length, b.length);
}

function dedupeRawTerritories(raw: RawTerritory[]): RawTerritory[] {
  const sorted = [...raw].sort((a, b) => {
    if (b.entries.length !== a.entries.length) {
      return b.entries.length - a.entries.length;
    }
    return b.priority - a.priority;
  });

  const kept: RawTerritory[] = [];

  for (const candidate of sorted) {
    const duplicate = kept.find((existing) => {
      if (existing.defaultLabel.toLowerCase() === candidate.defaultLabel.toLowerCase()) {
        return true;
      }
      if (existing.kind === candidate.kind) {
        return entryOverlap(existing.entries, candidate.entries) >= 0.75;
      }
      return entryOverlap(existing.entries, candidate.entries) >= 0.9;
    });

    if (duplicate) {
      for (const entry of candidate.entries) {
        if (!duplicate.entries.some((e) => e.id === entry.id)) {
          duplicate.entries.push(entry);
        }
      }
      duplicate.priority = Math.max(duplicate.priority, candidate.priority);
      duplicate.entries.sort(
        (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
      );
      continue;
    }

    kept.push({
      ...candidate,
      entries: sortedEntries(candidate.entries),
    });
  }

  return kept;
}

function analyzeEvolution(entries: JournalEntry[]): EmotionalTerritoryEvolution {
  if (entries.length < MIN_TERRITORY_ENTRIES) {
    return { whatChanged: null, whatCameBack: null, whatGotQuieter: null };
  }

  let whatChanged: string | null = null;
  let whatGotQuieter: string | null = null;
  let whatCameBack: string | null = null;

  if (entries.length >= 3) {
    const mid = Math.floor(entries.length / 2);
    const early = entries.slice(0, mid);
    const late = entries.slice(mid);
    const earlyAvg = roundAvg(early.map((e) => e.reflection.emotionalIntensity));
    const lateAvg = roundAvg(late.map((e) => e.reflection.emotionalIntensity));
    const earlyHedge = roundAvg(early.map((e) => countMatches(e.transcript, HEDGE_RE)));
    const lateHedge = roundAvg(late.map((e) => countMatches(e.transcript, HEDGE_RE)));
    const earlyDirect = roundAvg(early.map((e) => countMatches(e.transcript, DIRECT_RE)));
    const lateDirect = roundAvg(late.map((e) => countMatches(e.transcript, DIRECT_RE)));

    if (lateAvg <= earlyAvg - 1 || lateHedge <= earlyHedge - 0.8) {
      whatChanged = "This felt lighter later on.";
    } else if (lateAvg >= earlyAvg + 1) {
      whatChanged = "This took up more room over time.";
    } else if (lateDirect >= earlyDirect + 0.8) {
      whatChanged = "Your language around this shifted.";
    }
  }

  for (let i = 1; i < entries.length - 1; i += 1) {
    const gap = daysBetweenKeys(
      toDayKey(entries[i - 1].createdAt),
      toDayKey(entries[i + 1].createdAt),
    );
    if (gap >= GAP_DAYS * 2) {
      whatGotQuieter = "This went quiet for a while.";
      break;
    }
  }

  if (entries.length >= 3) {
    const last = entries[entries.length - 1];
    const prev = entries[entries.length - 2];
    const returnGap = daysBetweenKeys(toDayKey(prev.createdAt), toDayKey(last.createdAt));
    if (returnGap >= GAP_DAYS) {
      whatCameBack = "You came back to this later.";
    }
  }

  return { whatChanged, whatCameBack, whatGotQuieter };
}

function continuityLines(entries: JournalEntry[], evolution: EmotionalTerritoryEvolution): string[] {
  const lines: string[] = [];

  if (entries.length >= 3) {
    lines.push("You've returned here a few times.");
  } else {
    lines.push("A small thread is forming here.");
  }

  const latestGap = daysBetweenKeys(
    toDayKey(entries[entries.length - 1].createdAt),
    toDayKey(new Date().toISOString()),
  );
  if (latestGap >= GAP_DAYS * 2) {
    lines.push("This has been in the background lately.");
  }

  if (evolution.whatCameBack) {
    lines.push(evolution.whatCameBack);
  }

  return lines.slice(0, 2);
}

function toEmotionalTerritory(raw: RawTerritory, slugCounts: Map<string, number>): EmotionalTerritory {
  const entries = sortedEntries(raw.entries);
  const first = entries[0];
  const last = entries[entries.length - 1];
  const evolution = analyzeEvolution(entries);
  const label = resolveTerritoryLabel(raw.id, raw.defaultLabel);
  const baseSlug = toSlug(raw.defaultLabel);
  const count = (slugCounts.get(baseSlug) ?? 0) + 1;
  slugCounts.set(baseSlug, count);
  const slug = count > 1 ? `${baseSlug}-${count}` : baseSlug;

  const relatedReflections: EmotionalTerritoryReflection[] = entries
    .slice(-MAX_RELATED_REFLECTIONS)
    .map((entry) => ({
      entryId: entry.id,
      dateLabel: formatEntryDate(entry.createdAt),
      snippet: snippet(entry),
    }));

  return {
    id: raw.id,
    slug,
    label,
    defaultLabel: raw.defaultLabel,
    kind: raw.kind,
    entryIds: entries.map((e) => e.id),
    mentionCount: entries.length,
    continuityLines: continuityLines(entries, evolution),
    evolution,
    relatedReflections,
    firstAppearance: first.createdAt,
    latestAppearance: last.createdAt,
    firstAppearanceLabel: formatShortDate(first.createdAt),
    latestAppearanceLabel: formatShortDate(last.createdAt),
  };
}

/** Detect soft life-context territories from reflections — no setup wizard. */
export function buildEmotionalTerritoriesReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): EmotionalTerritoriesReport {
  const sorted = sortedEntries(entries);
  const raw = dedupeRawTerritories([
    ...buildPresetTerritories(sorted),
    ...buildPersonTerritories(sorted),
    ...buildTopicTerritories(sorted),
  ]);

  const slugCounts = new Map<string, number>();
  const territories = raw
    .map((row) => toEmotionalTerritory(row, slugCounts))
    .sort((a, b) => {
      const timeDiff =
        new Date(b.latestAppearance).getTime() - new Date(a.latestAppearance).getTime();
      if (timeDiff !== 0) return timeDiff;
      return b.mentionCount - a.mentionCount;
    });

  return {
    generatedAt: new Date().toISOString(),
    hasData: territories.length > 0,
    territories,
  };
}

export function listEmotionalTerritories(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
  limit?: number,
): EmotionalTerritory[] {
  const { territories } = buildEmotionalTerritoriesReport(entries);
  return limit ? territories.slice(0, limit) : territories;
}

export function getEmotionalTerritoryBySlug(
  entries: JournalEntry[],
  slug: string,
): EmotionalTerritory | null {
  const { territories } = buildEmotionalTerritoriesReport(entries);
  return territories.find((territory) => territory.slug === slug) ?? null;
}

export function getEmotionalTerritoryById(
  entries: JournalEntry[],
  territoryId: string,
): EmotionalTerritory | null {
  const { territories } = buildEmotionalTerritoriesReport(entries);
  return territories.find((territory) => territory.id === territoryId) ?? null;
}

export function territoriesForEntry(
  entries: JournalEntry[],
  entryId: string,
  limit = 3,
): EmotionalTerritory[] {
  return listEmotionalTerritories(entries)
    .filter((territory) => territory.entryIds.includes(entryId))
    .slice(0, limit);
}

export function entriesForTerritory(
  entries: JournalEntry[],
  territoryId: string | null | undefined,
): JournalEntry[] {
  if (!territoryId) return entries;
  const territory = getEmotionalTerritoryById(entries, territoryId);
  if (!territory) return entries;
  const allowed = new Set(territory.entryIds);
  return entries.filter((entry) => allowed.has(entry.id));
}

export function formatTerritoryDateRange(territory: EmotionalTerritory): string {
  const start = territory.firstAppearanceLabel;
  const end = territory.latestAppearanceLabel;
  return start === end ? start : `${start} – ${end}`;
}

export function entryMatchesTerritory(
  entry: JournalEntry,
  territoryId: string,
  allEntries: JournalEntry[] = getMemoryEligibleEntries(),
): boolean {
  const territory = getEmotionalTerritoryById(allEntries, territoryId);
  return territory?.entryIds.includes(entry.id) ?? false;
}
