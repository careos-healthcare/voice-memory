import { z } from "zod";

export interface WeeklyReflectionEntry {
  entryId: string;
  text: string;
  timestamp: string;
  embedding?: number[];
}

export interface VerbatimCitation {
  text: string;
  entryId: string;
  timestamp: string;
}

export interface WeeklyRecap {
  summary: string;
  keyThemes: string[];
  emotionalArc: string;
  verbatimCitations: VerbatimCitation[];
}

const controlChars = /[\u0000-\u001f]/g;

function sanitizedText(max: number) {
  return z
    .string()
    .transform((value) => value.replace(controlChars, "").trim().slice(0, max))
    .refine((value) => value.length > 0);
}

const weeklyEntrySchema = z.object({
  entryId: sanitizedText(80),
  text: sanitizedText(2000),
  timestamp: sanitizedText(40),
  embedding: z.array(z.number().finite()).optional(),
});

const weeklyAggregateSchema = z.object({
  weekEndingKey: sanitizedText(40),
  entryCount: z.number().finite(),
  lastWeekEntryCount: z.number().finite(),
  dominantEmotions: z.array(sanitizedText(200)),
  repeatedConcerns: z.array(sanitizedText(200)),
  repeatedEntities: z.array(sanitizedText(200)),
  recurringThemes: z.array(sanitizedText(200)),
  observationHighlights: z.array(sanitizedText(200)),
  avgIntensityThisWeek: z.number().finite().nullable().optional(),
  avgIntensityLastWeek: z.number().finite().nullable().optional(),
  emotionalShiftLabel: sanitizedText(80).optional(),
});

export type ParsedWeeklyReflection =
  | { kind: "entries"; entries: WeeklyReflectionEntry[] }
  | { kind: "aggregate"; aggregate: SanitizedWeeklyAggregate };

/** Requires every list and string, then strips control characters and trims. */
export function parseWeeklyReflectionBody(input: unknown): ParsedWeeklyReflection | string {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    return "Weekly reflection body must be an object.";
  }
  const body = input as Record<string, unknown>;
  if ("transcripts" in body && body.transcripts !== undefined && !Array.isArray(body.transcripts)) {
    return "transcripts must be an array.";
  }
  if ("entries" in body) {
    if (!Array.isArray(body.entries)) return "entries must be an array.";
    const parsed = z
      .object({
        entries: z.array(weeklyEntrySchema),
        transcripts: z.array(sanitizedText(4000)).optional(),
      })
      .safeParse({ entries: body.entries, transcripts: body.transcripts });
    if (!parsed.success) return "Each entry needs an id, text, and timestamp.";
    return { kind: "entries", entries: parsed.data.entries };
  }

  const parsed = weeklyAggregateSchema.safeParse(body);
  if (!parsed.success) return "Weekly reflection list fields must be arrays.";
  const data = parsed.data;
  return {
    kind: "aggregate",
    aggregate: {
      weekEndingKey: data.weekEndingKey,
      entryCount: data.entryCount,
      lastWeekEntryCount: data.lastWeekEntryCount,
      dominantEmotions: data.dominantEmotions,
      repeatedConcerns: data.repeatedConcerns,
      repeatedEntities: data.repeatedEntities,
      recurringThemes: data.recurringThemes,
      observationHighlights: data.observationHighlights,
      avgIntensityThisWeek: data.avgIntensityThisWeek ?? null,
      avgIntensityLastWeek: data.avgIntensityLastWeek ?? null,
      emotionalShiftLabel: data.emotionalShiftLabel ?? "unchanged",
    },
  };
}

const STOP = new Set([
  "a", "an", "the", "and", "or", "to", "of", "in", "on", "for", "with", "i", "you", "it", "is", "was",
]);

export function weeklyInputError(body: {
  entries?: unknown;
  transcripts?: unknown;
}): string | null {
  if (body.entries !== undefined && !Array.isArray(body.entries)) {
    return "entries must be an array.";
  }
  if (body.transcripts !== undefined && !Array.isArray(body.transcripts)) {
    return "transcripts must be an array.";
  }
  return null;
}

function cleanString(value: unknown, max = 200): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.replace(/[\u0000-\u001f]/g, "").trim().slice(0, max);
  return trimmed.length > 0 ? trimmed : null;
}

function cleanStringList(value: unknown): string[] | null {
  if (!Array.isArray(value)) return null;
  const items: string[] = [];
  for (const item of value) {
    const text = cleanString(item);
    if (!text) continue;
    items.push(text);
  }
  return items;
}

export function sanitizeWeeklyEntries(value: unknown): WeeklyReflectionEntry[] | null {
  if (!Array.isArray(value)) return null;
  const entries: WeeklyReflectionEntry[] = [];
  for (const item of value) {
    if (!item || typeof item !== "object") return null;
    const record = item as Record<string, unknown>;
    const entryId = cleanString(record.entryId, 80);
    const text = cleanString(record.text, 2000);
    const timestamp = cleanString(record.timestamp, 40);
    if (!entryId || !text || !timestamp) return null;
    const embedding = Array.isArray(record.embedding)
      ? record.embedding.filter((point): point is number => typeof point === "number" && Number.isFinite(point))
      : undefined;
    entries.push({ entryId, text, timestamp, embedding });
  }
  return entries;
}

export interface SanitizedWeeklyAggregate {
  weekEndingKey: string;
  entryCount: number;
  lastWeekEntryCount: number;
  dominantEmotions: string[];
  repeatedConcerns: string[];
  repeatedEntities: string[];
  recurringThemes: string[];
  avgIntensityThisWeek: number | null;
  avgIntensityLastWeek: number | null;
  emotionalShiftLabel: string;
  observationHighlights: string[];
}

export function sanitizeWeeklyAggregate(body: Record<string, unknown>): SanitizedWeeklyAggregate | string {
  const weekEndingKey = cleanString(body.weekEndingKey, 40);
  const emotionalShiftLabel = cleanString(body.emotionalShiftLabel, 80) ?? "unchanged";
  const dominantEmotions = cleanStringList(body.dominantEmotions);
  const repeatedConcerns = cleanStringList(body.repeatedConcerns);
  const repeatedEntities = cleanStringList(body.repeatedEntities);
  const recurringThemes = cleanStringList(body.recurringThemes);
  const observationHighlights = cleanStringList(body.observationHighlights);
  if (
    !weekEndingKey ||
    !dominantEmotions ||
    !repeatedConcerns ||
    !repeatedEntities ||
    !recurringThemes ||
    !observationHighlights ||
    typeof body.entryCount !== "number" ||
    typeof body.lastWeekEntryCount !== "number"
  ) {
    return "Weekly reflection list fields must be arrays.";
  }
  const intensity = (value: unknown) =>
    typeof value === "number" && Number.isFinite(value) ? value : null;
  return {
    weekEndingKey,
    entryCount: body.entryCount,
    lastWeekEntryCount: body.lastWeekEntryCount,
    dominantEmotions,
    repeatedConcerns,
    repeatedEntities,
    recurringThemes,
    avgIntensityThisWeek: intensity(body.avgIntensityThisWeek),
    avgIntensityLastWeek: intensity(body.avgIntensityLastWeek),
    emotionalShiftLabel,
    observationHighlights,
  };
}

export function cosineSimilarity(left: number[], right: number[]): number {
  const length = Math.min(left.length, right.length);
  if (length === 0) return 0;
  let dot = 0;
  let leftNorm = 0;
  let rightNorm = 0;
  for (let i = 0; i < length; i += 1) {
    dot += left[i] * right[i];
    leftNorm += left[i] * left[i];
    rightNorm += right[i] * right[i];
  }
  if (leftNorm === 0 || rightNorm === 0) return 0;
  return dot / Math.sqrt(leftNorm * rightNorm);
}

function centroid(vectors: number[][]): number[] | null {
  if (vectors.length === 0) return null;
  const width = vectors[0].length;
  const sum = Array.from({ length: width }, () => 0);
  for (const vector of vectors) {
    for (let i = 0; i < width; i += 1) sum[i] += vector[i] ?? 0;
  }
  return sum.map((value) => value / vectors.length);
}

function inWindow(timestamp: string, start: Date, end: Date): boolean {
  const at = new Date(timestamp);
  return at >= start && at < end;
}

export function aggregateWeeklyRecap(
  entries: WeeklyReflectionEntry[],
  now = new Date(),
): WeeklyRecap & { priorWeekSimilarity: number | null } {
  const end = new Date(now);
  const start = new Date(end.getTime() - 7 * 24 * 60 * 60 * 1000);
  const priorStart = new Date(start.getTime() - 7 * 24 * 60 * 60 * 1000);
  const current = entries.filter((entry) => inWindow(entry.timestamp, start, end));
  const prior = entries.filter((entry) => inWindow(entry.timestamp, priorStart, start));

  const currentCentroid = centroid(
    current.flatMap((entry) => (entry.embedding ? [entry.embedding] : [])),
  );
  const priorCentroid = centroid(
    prior.flatMap((entry) => (entry.embedding ? [entry.embedding] : [])),
  );
  const priorWeekSimilarity =
    currentCentroid && priorCentroid
      ? cosineSimilarity(currentCentroid, priorCentroid)
      : null;

  const counts = new Map<string, number>();
  for (const entry of current) {
    for (const word of entry.text.toLowerCase().split(/[^a-z0-9]+/)) {
      if (word.length < 4 || STOP.has(word)) continue;
      counts.set(word, (counts.get(word) ?? 0) + 1);
    }
  }
  const keyThemes = [...counts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([word]) => word);

  const emotionalArc =
    priorWeekSimilarity == null
      ? "This week stands on its own."
      : priorWeekSimilarity >= 0.8
        ? "This week continues last week's thread."
        : "This week shifts away from last week.";

  const verbatimCitations = current.slice(0, 3).map((entry) => ({
    text: entry.text.trim().slice(0, 140),
    entryId: entry.entryId,
    timestamp: entry.timestamp,
  }));

  const themeLine = keyThemes.length > 0 ? keyThemes.join(", ") : "a few quiet notes";
  return {
    summary: `Across ${current.length} moments you returned to ${themeLine}. ${emotionalArc}`,
    keyThemes,
    emotionalArc,
    verbatimCitations,
    priorWeekSimilarity,
  };
}

export async function synthesizeWeeklyRecap(
  entries: WeeklyReflectionEntry[],
  now = new Date(),
  model?: (draft: WeeklyRecap) => Promise<Partial<WeeklyRecap>>,
): Promise<WeeklyRecap> {
  const draft = aggregateWeeklyRecap(entries, now);
  if (!model) {
    return {
      summary: draft.summary,
      keyThemes: draft.keyThemes,
      emotionalArc: draft.emotionalArc,
      verbatimCitations: draft.verbatimCitations,
    };
  }
  const overlay = await model(draft);
  return {
    summary: overlay.summary?.trim() || draft.summary,
    keyThemes: Array.isArray(overlay.keyThemes) ? overlay.keyThemes : draft.keyThemes,
    emotionalArc: overlay.emotionalArc?.trim() || draft.emotionalArc,
    verbatimCitations: Array.isArray(overlay.verbatimCitations)
      ? overlay.verbatimCitations
      : draft.verbatimCitations,
  };
}
