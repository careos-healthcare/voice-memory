import { toDayKey } from "@/lib/dates";
import type { JournalEntry } from "@/types/journal";
import type { EmotionalEvolutionSignal } from "@/types/pattern-insights";

const DAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

function dayName(iso: string): string {
  const [y, m, d] = toDayKey(iso).split("-").map(Number);
  return DAY_NAMES[new Date(y, m - 1, d).getDay()];
}

export function detectEmotionalEvolution(
  entries: JournalEntry[],
  currentEntryId: string,
): EmotionalEvolutionSignal[] {
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const currentIndex = sorted.findIndex((e) => e.id === currentEntryId);
  if (currentIndex < 0) return [];

  const current = sorted[currentIndex];
  const prior = sorted.slice(0, currentIndex + 1);
  const results: EmotionalEvolutionSignal[] = [];

  if (prior.length >= 3) {
    const recent = prior.slice(-6);
    const intensities = recent.map((e) => e.reflection.emotionalIntensity);
    const firstHalf = intensities.slice(0, Math.floor(intensities.length / 2));
    const secondHalf = intensities.slice(Math.floor(intensities.length / 2));
    const avg = (arr: number[]) => arr.reduce((a, b) => a + b, 0) / arr.length;
    const delta = avg(secondHalf) - avg(firstHalf);

    if (Math.abs(delta) >= 1.5) {
      results.push({
        id: "intensity-drift",
        kind: "intensity_drift",
        label: delta > 0 ? "Intensity drifting upward" : "Intensity drifting downward",
        detail:
          delta > 0
            ? `Across your recent entries, emotional intensity averages higher than earlier — language is carrying more weight lately.`
            : `Across your recent entries, emotional intensity averages lower than earlier — your descriptions sound less charged over this span.`,
      });
    }
  }

  if (prior.length >= 4) {
    const byDay = new Map<string, { count: number; avgIntensity: number; moods: string[] }>();
    for (const entry of prior) {
      const day = dayName(entry.createdAt);
      const row = byDay.get(day) ?? { count: 0, avgIntensity: 0, moods: [] };
      row.count += 1;
      row.avgIntensity += entry.reflection.emotionalIntensity;
      row.moods.push(entry.reflection.mood);
      byDay.set(day, row);
    }

    for (const [day, data] of byDay.entries()) {
      if (data.count >= 2) {
        const avg = Math.round((data.avgIntensity / data.count) * 10) / 10;
        const dominantMood = data.moods[data.moods.length - 1];
        results.push({
          id: `dow-${day}`,
          kind: "day_of_week",
          label: `${day} pattern`,
          detail: `You tend to record on ${day}s with average intensity ${avg}/10 — often around "${dominantMood}" in your words.`,
        });
        break;
      }
    }
  }

  const themeIntensity = new Map<string, number[]>();
  for (const entry of prior) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      const list = themeIntensity.get(key) ?? [];
      list.push(entry.reflection.emotionalIntensity);
      themeIntensity.set(key, list);
    }
  }

  for (const [theme, intensities] of themeIntensity.entries()) {
    if (intensities.length >= 2) {
      const avg = intensities.reduce((a, b) => a + b, 0) / intensities.length;
      if (avg >= 6) {
        results.push({
          id: `trigger-${theme}`,
          kind: "recurring_trigger",
          label: `Recurring trigger: "${theme}"`,
          detail: `When "${theme}" appears in your entries, intensity averages ${Math.round(avg * 10) / 10}/10 — a recurring emotional context in your language.`,
        });
        break;
      }
    }
  }

  if (prior.length >= 4) {
    const moods = prior.slice(-6).map((e) => e.reflection.mood.toLowerCase());
    let alternations = 0;
    for (let i = 1; i < moods.length; i += 1) {
      if (moods[i] !== moods[i - 1]) alternations += 1;
    }
    if (alternations >= moods.length - 2 && moods.length >= 4) {
      results.push({
        id: "emotional-cycle",
        kind: "emotional_cycle",
        label: "Recurring emotional cycle",
        detail: `Your last ${moods.length} entries shift mood often (${moods.join(" → ")}) — an back-and-forth cycle in how you describe your days.`,
      });
    }
  }

  const currentThemes = new Set(current.reflection.recurringThemes.map((t) => t.toLowerCase()));
  const contextEntries = prior.filter((e) =>
    e.reflection.recurringThemes.some((t) => currentThemes.has(t.toLowerCase())),
  );

  if (contextEntries.length >= 2) {
    const moods = [...new Set(contextEntries.map((e) => e.reflection.mood))];
    results.push({
      id: "recurring-context",
      kind: "recurring_context",
      label: "Recurring emotional context",
      detail: `This entry's themes show up across ${contextEntries.length} reflections with moods like ${moods.slice(0, 3).join(", ")} — a longitudinal thread in your words.`,
    });
  }

  const seen = new Set<string>();
  return results.filter((r) => {
    if (seen.has(r.kind)) return false;
    seen.add(r.kind);
    return true;
  }).slice(0, 5);
}
