/**
 * Thematic Lens prompt contract — injects life-stage context into
 * fact_ledger evaluation without altering ArchiveInsightKind taxonomy.
 *
 * Lens blocks are system-instruction addenda only. They must never
 * introduce new insight kinds or replace Evidence Method rules.
 */

import type { LifeStageLens } from "@/types/user-context";
import { normalizeLifeStageLens } from "@/types/user-context";
import { CAREER_TRANSITION_SYSTEM_PROMPT_INJECTION } from "@/lib/lenses/career-transition-lens";
import { GRIEF_LOSS_SYSTEM_PROMPT_INJECTION } from "@/lib/lenses/grief-loss-lens";
import { NEW_PARENT_SYSTEM_PROMPT_INJECTION } from "@/lib/lenses/new-parent-lens";
import { RECOVERY_SYSTEM_PROMPT_INJECTION } from "@/lib/lenses/recovery-lens";

export const LIFE_STAGE_LENS_HEADER =
  "THEMATIC LENS — CONTEXT ONLY (does not change insight kinds)";

/** Situational awareness per lens — observation tone only, no new categories. */
export const LIFE_STAGE_LENS_INSTRUCTIONS: Record<
  Exclude<LifeStageLens, "default">,
  string
> = {
  newParent: NEW_PARENT_SYSTEM_PROMPT_INJECTION,
  careerTransition: CAREER_TRANSITION_SYSTEM_PROMPT_INJECTION,
  recovery: RECOVERY_SYSTEM_PROMPT_INJECTION,
  griefLoss: GRIEF_LOSS_SYSTEM_PROMPT_INJECTION,
};

export interface FactLedgerPromptContextInput {
  /** Base Evidence Method system prompt — unchanged taxonomy rules. */
  baseSystemPrompt: string;
  /** Optional thematic lens from user settings. */
  activeLens?: LifeStageLens | null;
}

/**
 * Appends a lens-specific system block when [activeLens] is set and not
 * `default`. Returns [baseSystemPrompt] unchanged when no lens applies.
 */
export function composeFactLedgerSystemPrompt(
  input: FactLedgerPromptContextInput,
): string {
  const lens = normalizeLifeStageLens(input.activeLens ?? "default");
  const block = buildLifeStageLensSystemBlock(lens);
  if (!block) {
    return input.baseSystemPrompt;
  }
  return `${input.baseSystemPrompt}\n\n${block}`;
}

/** Lens block only — empty string for `default` or missing lens. */
export function buildLifeStageLensSystemBlock(
  lens: LifeStageLens | null | undefined,
): string {
  const normalized = normalizeLifeStageLens(lens ?? "default");
  if (normalized === "default") {
    return "";
  }

  return [
    LIFE_STAGE_LENS_HEADER,
    LIFE_STAGE_LENS_INSTRUCTIONS[normalized],
    "ArchiveInsightKind taxonomy is unchanged — still choose among belief, beliefChange, theme, contradiction, blindSpot, chapter, weeklyStory, surprise, and challenge.",
    "This lens adjusts contextual reading of fact_ledger entries only; it does not authorize new categories or clinical labels.",
  ].join("\n");
}
