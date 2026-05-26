import { LAUNCH_EVENTS, readLocalEvents } from "@/lib/local-analytics";
import { OPEN_LOOP_EVENTS } from "@/lib/open-loops/open-loop-observation";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning";
import { FIRST_WEEK_RETENTION_EVENTS } from "@/lib/retention/first-week-observation";
import { RECURRENCE_DENSITY_EVENTS } from "@/lib/retention/recurrence-density";
import type { ProductPressureWarning } from "@/types/behavior-truth";
import type { LocalAnalyticsEvent } from "@/lib/local-analytics";
import type { JournalEntry } from "@/types/journal";

const CONTINUITY_SURFACE_EVENTS = new Set([
  CALLBACK_LEARNING_EVENTS.shown,
  OPEN_LOOP_EVENTS.promptShown,
  OPEN_LOOP_EVENTS.resurfacingShown,
  OPEN_LOOP_EVENTS.returnPromptShown,
  FIRST_WEEK_RETENTION_EVENTS.returnPromptOpened,
  "comprehension_prompt_shown",
  RECURRENCE_DENSITY_EVENTS.promptShown,
  "magic_candidate_shown",
  "day_two_return",
]);

const DISMISS_EVENTS = new Set([
  OPEN_LOOP_EVENTS.promptDismissed,
  CALLBACK_LEARNING_EVENTS.dismissed,
  CALLBACK_LEARNING_EVENTS.ignored,
  RECURRENCE_DENSITY_EVENTS.promptDismissed,
  "comprehension_prompt_ignored",
]);

export function computeProductPressureWarnings(
  events: LocalAnalyticsEvent[],
  entries: JournalEntry[],
): ProductPressureWarning[] {
  const warnings: ProductPressureWarning[] = [];
  const secondReflectionAt = events.find(
    (e) => e.name === LAUNCH_EVENTS.secondReflectionCreated,
  )?.at;
  const secondMs = secondReflectionAt ? new Date(secondReflectionAt).getTime() : null;

  let surfacesBeforeHabit = 0;
  for (const event of events) {
    if (!CONTINUITY_SURFACE_EVENTS.has(event.name)) continue;
    if (secondMs === null || new Date(event.at).getTime() <= secondMs) {
      surfacesBeforeHabit += 1;
    }
  }

  if (surfacesBeforeHabit >= 5) {
    warnings.push({
      severity: "concern",
      plain: `Users are seeing ${surfacesBeforeHabit}+ continuity surfaces before forming a reflection habit (second reflection).`,
    });
  } else if (surfacesBeforeHabit >= 3) {
    warnings.push({
      severity: "watch",
      plain: `${surfacesBeforeHabit} continuity surfaces appeared before the second reflection — watch for clutter.`,
    });
  }

  const dismissCount = events.filter((e) => DISMISS_EVENTS.has(e.name)).length;
  const callbackShown = events.filter((e) => e.name === CALLBACK_LEARNING_EVENTS.shown).length;
  const loopPrompts = events.filter((e) => e.name === OPEN_LOOP_EVENTS.promptShown).length;

  if (dismissCount >= 4 && dismissCount >= callbackShown + loopPrompts) {
    warnings.push({
      severity: "concern",
      plain: "Ignored or dismissed prompts are stacking — continuity surfaces may be fatiguing.",
    });
  }

  if (callbackShown >= 8 && loopPrompts >= 4) {
    warnings.push({
      severity: "watch",
      plain: "Callback and open-loop prompts overlap often — risk of duplicate emotional nudges.",
    });
  }

  const reflectionCount = entries.length;
  const activeSurfaces = new Set(
    events
      .filter((e) => CONTINUITY_SURFACE_EVENTS.has(e.name))
      .map((e) => e.name),
  ).size;

  if (reflectionCount <= 2 && activeSurfaces >= 4) {
    warnings.push({
      severity: "concern",
      plain: "Feature density is high relative to reflections — the product may feel like an introspection operating system.",
    });
  }

  if (warnings.length === 0 && events.length > 0) {
    warnings.push({
      severity: "watch",
      plain: "No major pressure signals on this device yet — keep measuring on real mobile use.",
    });
  }

  return warnings;
}
