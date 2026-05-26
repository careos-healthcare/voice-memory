import { buildAtmosphereSignals } from "@/lib/atmosphere/memory-atmosphere";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  AtmosphereChoice,
  AtmosphereFingerprint,
  AtmosphereStyle,
  EmotionalAtmosphereLabel,
  EntryAtmosphereMeta,
} from "@/types/atmosphere";

export const ATMOSPHERE_SECTION_TITLE = "A visual echo";
export const ATMOSPHERE_SECTION_DISCLAIMER =
  "Generated images may not match what happened.";
export const ATMOSPHERE_EXPAND_LABEL = "Add a visual echo";
export const ATMOSPHERE_GENERATE_ANOTHER = "Generate another";

export const EMOTIONAL_ATMOSPHERE_CATALOG: Array<{
  emotionalLabel: EmotionalAtmosphereLabel;
  displayLabel: string;
  style: AtmosphereStyle;
  hint: string;
  paletteIntent: string;
}> = [
  {
    emotionalLabel: "waiting",
    displayLabel: "Waiting",
    style: "rainy-window",
    hint: "Held breath, cool stillness",
    paletteIntent: "cool grey-blue vertical stillness",
  },
  {
    emotionalLabel: "pressure",
    displayLabel: "Pressure",
    style: "dusk-field",
    hint: "Weighted dusk tones",
    paletteIntent: "muted violet-orange compression",
  },
  {
    emotionalLabel: "distance",
    displayLabel: "Distance",
    style: "foggy-street",
    hint: "Soft far-off haze",
    paletteIntent: "grey-violet atmospheric distance",
  },
  {
    emotionalLabel: "relief",
    displayLabel: "Relief",
    style: "soft-light",
    hint: "Diffused ease",
    paletteIntent: "pale neutral glow easing",
  },
  {
    emotionalLabel: "restlessness",
    displayLabel: "Restlessness",
    style: "abstract-color-field",
    hint: "Shifting color fields",
    paletteIntent: "restless abstract gradients",
  },
  {
    emotionalLabel: "uncertainty",
    displayLabel: "Uncertainty",
    style: "foggy-street",
    hint: "Indistinct edges",
    paletteIntent: "soft ambiguous haze",
  },
  {
    emotionalLabel: "soft-focus",
    displayLabel: "Soft focus",
    style: "soft-light",
    hint: "Gentle blur of light",
    paletteIntent: "diffused pale gradients",
  },
  {
    emotionalLabel: "calm-after-noise",
    displayLabel: "Calm after noise",
    style: "quiet-room",
    hint: "Warm quiet after clutter",
    paletteIntent: "warm neutral settling glow",
  },
  {
    emotionalLabel: "emotional-static",
    displayLabel: "Emotional static",
    style: "rainy-window",
    hint: "Static, not quite clear",
    paletteIntent: "abstract cool interference",
  },
];

const BANNED_WALLPAPER_LABELS = [
  "Foggy street",
  "Morning glow",
  "Quiet room",
  "Soft light",
  "Rainy window",
  "Dusk field",
  "Abstract color field",
];

const SCORE_RULES: Array<{
  emotionalLabel: EmotionalAtmosphereLabel;
  pattern: RegExp;
  weight: number;
}> = [
  { emotionalLabel: "waiting", pattern: /\b(wait|waiting|hold on|not yet|still waiting|on hold)\b/i, weight: 14 },
  { emotionalLabel: "pressure", pattern: /\b(pressure|deadline|urgent|overwhelm|crush|weight on)\b/i, weight: 14 },
  { emotionalLabel: "distance", pattern: /\b(far|distant|away from|drifted|apart|remote)\b/i, weight: 12 },
  { emotionalLabel: "relief", pattern: /\b(relieved|relief|lighter|eased|unclench|finally)\b/i, weight: 13 },
  { emotionalLabel: "restlessness", pattern: /\b(restless|can't settle|on edge|wired|agitated)\b/i, weight: 14 },
  { emotionalLabel: "uncertainty", pattern: /\b(unsure|uncertain|don't know|not sure|maybe|unclear)\b/i, weight: 12 },
  { emotionalLabel: "calm-after-noise", pattern: /\b(calm|quieter|settled|after the|once it stopped|noise died)\b/i, weight: 11 },
  { emotionalLabel: "emotional-static", pattern: /\b(static|stuck|numb|blank|foggy|can't think)\b/i, weight: 12 },
  { emotionalLabel: "soft-focus", pattern: /\b(soft|gentle|hazy|blur|tired|drained)\b/i, weight: 8 },
];

function catalogRow(label: EmotionalAtmosphereLabel) {
  const row = EMOTIONAL_ATMOSPHERE_CATALOG.find((item) => item.emotionalLabel === label);
  if (!row) throw new Error(`Unknown atmosphere label: ${label}`);
  return row;
}

function entryText(entry: JournalEntry): string {
  return [
    entry.transcript,
    entry.reflection.concreteObservation,
    entry.reflection.exactLanguagePattern,
    entry.reflection.hiddenConcern,
    entry.reflection.mood,
  ]
    .filter(Boolean)
    .join(" ");
}

function moodBoost(mood: string, intensity: number): Map<EmotionalAtmosphereLabel, number> {
  const boosts = new Map<EmotionalAtmosphereLabel, number>();
  const m = mood.toLowerCase();

  if (/anx|stress|tense|worr/.test(m)) {
    boosts.set("pressure", (boosts.get("pressure") ?? 0) + 10);
    boosts.set("uncertainty", (boosts.get("uncertainty") ?? 0) + 8);
    boosts.set("restlessness", (boosts.get("restlessness") ?? 0) + 6);
  }
  if (/calm|peace|steady|quiet/.test(m)) {
    boosts.set("calm-after-noise", (boosts.get("calm-after-noise") ?? 0) + 10);
    boosts.set("soft-focus", (boosts.get("soft-focus") ?? 0) + 8);
    boosts.set("relief", (boosts.get("relief") ?? 0) + 6);
  }
  if (/sad|low|heavy|tired|drain/.test(m)) {
    boosts.set("distance", (boosts.get("distance") ?? 0) + 8);
    boosts.set("emotional-static", (boosts.get("emotional-static") ?? 0) + 7);
    boosts.set("soft-focus", (boosts.get("soft-focus") ?? 0) + 6);
  }
  if (/hope|forward|better|clear/.test(m)) {
    boosts.set("relief", (boosts.get("relief") ?? 0) + 6);
    boosts.set("soft-focus", (boosts.get("soft-focus") ?? 0) + 5);
  }

  if (intensity >= 7) {
    boosts.set("pressure", (boosts.get("pressure") ?? 0) + 4);
    boosts.set("restlessness", (boosts.get("restlessness") ?? 0) + 3);
  }
  if (intensity <= 4) {
    boosts.set("soft-focus", (boosts.get("soft-focus") ?? 0) + 4);
    boosts.set("calm-after-noise", (boosts.get("calm-after-noise") ?? 0) + 3);
  }

  return boosts;
}

/** Rank emotional atmosphere options for this entry — internal styles unchanged. */
export function rankAtmosphereChoices(entry: JournalEntry): AtmosphereChoice[] {
  const text = entryText(entry);
  const scores = new Map<EmotionalAtmosphereLabel, number>();

  for (const row of EMOTIONAL_ATMOSPHERE_CATALOG) {
    scores.set(row.emotionalLabel, 0);
  }

  for (const rule of SCORE_RULES) {
    if (rule.pattern.test(text)) {
      scores.set(rule.emotionalLabel, (scores.get(rule.emotionalLabel) ?? 0) + rule.weight);
    }
  }

  for (const [label, boost] of moodBoost(
    entry.reflection.mood ?? "",
    entry.reflection.emotionalIntensity,
  )) {
    scores.set(label, (scores.get(label) ?? 0) + boost);
  }

  const signals = buildAtmosphereSignals(entry);
  if (signals.weatherHint) {
    scores.set("waiting", (scores.get("waiting") ?? 0) + 4);
    scores.set("emotional-static", (scores.get("emotional-static") ?? 0) + 3);
  }
  if (signals.timeOfDay === "night") {
    scores.set("distance", (scores.get("distance") ?? 0) + 3);
  }
  if (signals.timeOfDay === "morning") {
    scores.set("relief", (scores.get("relief") ?? 0) + 2);
  }

  return EMOTIONAL_ATMOSPHERE_CATALOG.map((row) => ({
    emotionalLabel: row.emotionalLabel,
    displayLabel: row.displayLabel,
    style: row.style,
    hint: row.hint,
    score: scores.get(row.emotionalLabel) ?? 0,
  })).sort((a, b) => b.score - a.score || a.displayLabel.localeCompare(b.displayLabel));
}

export interface AtmospherePickerPresentation {
  primary: AtmosphereChoice;
  alternate: AtmosphereChoice;
  orderedChoices: AtmosphereChoice[];
}

export function buildAtmospherePickerPresentation(
  entry: JournalEntry,
): AtmospherePickerPresentation {
  const orderedChoices = rankAtmosphereChoices(entry);
  const primary = orderedChoices[0] ?? catalogRow("soft-focus");
  const alternate =
    orderedChoices.find((row) => row.emotionalLabel !== primary.emotionalLabel) ??
    orderedChoices[1] ??
    catalogRow("distance");

  return { primary, alternate, orderedChoices };
}

/** One grounded context line — conservative, non-clinical. */
export function pickEmotionalContextLine(entry: JournalEntry): string {
  const text = entryText(entry).toLowerCase();
  const mood = entry.reflection.mood?.toLowerCase() ?? "";

  const hasWait = /\b(wait|waiting|hold on|not yet)\b/i.test(text);
  const hasPressure = /\b(pressure|deadline|urgent|overwhelm)\b/i.test(text);
  const hasNoiseThenCalm =
    /\b(noise|loud|chaos|argument|busy).*(calm|quiet|settled|stopped)/i.test(text) ||
    /\b(calm|quiet|settled).*(after|since).*(noise|loud|fight|day)/i.test(text);
  const hasTenseForward =
    (/\b(tense|anxious|tight|worried)\b/i.test(text) || /anx|stress|tense/.test(mood)) &&
    (/\b(forward|hope|next|move|progress|trying)\b/i.test(text) || /hope|determined/.test(mood));
  const hasRestless = /\b(restless|on edge|can't settle|agitated)\b/i.test(text);
  const hasUncertain = /\b(unsure|uncertain|don't know|not sure|unclear)\b/i.test(text);
  const hasRelief = /\b(relieved|relief|lighter|eased|finally)\b/i.test(text);
  const hasDistance = /\b(far|distant|away|drifted|apart)\b/i.test(text);

  if (hasWait && hasPressure) return "This moment carried pressure and waiting.";
  if (hasTenseForward) return "This sounded tense but still forward-moving.";
  if (hasNoiseThenCalm) return "This felt like calm after noise.";
  if (hasRestless) return "This had a restless, unsettled edge.";
  if (hasRelief) return "This carried a sense of relief.";
  if (hasUncertain) return "This held uncertainty without a clear answer.";
  if (hasDistance) return "This felt held at a distance.";
  if (/calm|peace|quiet|steady/.test(mood)) return "This felt like calm after noise.";
  if (/anx|stress|tense|worr/.test(mood)) return "This sounded tense but still forward-moving.";
  if (entry.reflection.emotionalIntensity >= 7) return "This moment carried pressure and waiting.";

  return "This moment had a particular emotional tone.";
}

export function buildAtmosphereFingerprint(
  entryId: string,
  emotionalLabel: EmotionalAtmosphereLabel,
  createdAt: string,
): AtmosphereFingerprint {
  const row = catalogRow(emotionalLabel);
  return {
    label: row.displayLabel,
    emotionalLabel,
    tone: row.hint,
    paletteIntent: row.paletteIntent,
    style: row.style,
    sourceEntryId: entryId,
    createdAt,
  };
}

export function emotionalLabelForStyle(style: AtmosphereStyle): EmotionalAtmosphereLabel {
  const match = EMOTIONAL_ATMOSPHERE_CATALOG.find((row) => row.style === style);
  return match?.emotionalLabel ?? "soft-focus";
}

export function resolveAtmosphereFingerprint(
  meta: EntryAtmosphereMeta,
): AtmosphereFingerprint | null {
  if (meta.fingerprint) return meta.fingerprint;
  if (!meta.atmosphereId) return null;
  const label = meta.emotionalLabel ?? emotionalLabelForStyle(meta.style);
  return buildAtmosphereFingerprint(meta.atmosphereId, label, meta.createdAt);
}

/** Entries that share an atmosphere anchor for resurfacing. */
export function findEntriesWithAtmosphereAnchor(
  fingerprint: AtmosphereFingerprint,
  entries = getMemoryEligibleEntries(),
): JournalEntry[] {
  return entries.filter((entry) => {
    if (!entry.atmosphere) return false;
    const fp = resolveAtmosphereFingerprint(entry.atmosphere);
    if (!fp) return false;
    return (
      fp.emotionalLabel === fingerprint.emotionalLabel ||
      fp.style === fingerprint.style
    );
  });
}

export function atmosphereAnchorDisplayLabel(entry: JournalEntry): string | null {
  const fp = entry.atmosphere ? resolveAtmosphereFingerprint(entry.atmosphere) : null;
  return fp?.label ?? null;
}

export function isBannedWallpaperLabel(text: string): boolean {
  return BANNED_WALLPAPER_LABELS.some(
    (banned) => banned.toLowerCase() === text.trim().toLowerCase(),
  );
}
