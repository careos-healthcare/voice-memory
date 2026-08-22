import "server-only";

import type { CuriosityEvidenceGateResult, CuriosityHook, CuriosityNotificationMessage } from "./types";

const GENERIC_PROMPT_PATTERNS: readonly RegExp[] = [
  /^what'?s on your mind/i,
  /^how are you feeling/i,
  /^time to (reflect|check in|journal)/i,
  /^don'?t forget to (write|record|reflect)/i,
  /^ready for your (daily|next) (reflection|entry)/i,
  /^come back when you'?re ready/i,
  /^we miss you/i,
  /^you haven'?t written/i,
];

const TITLE = "From your archive";

export function isGenericCuriosityPrompt(body: string): boolean {
  const trimmed = body.trim();
  if (trimmed.length < 24) return true;
  return GENERIC_PROMPT_PATTERNS.some((pattern) => pattern.test(trimmed));
}

/**
 * Builds push copy strictly from `fact_ledger` evidence — never generic nudges.
 */
export function buildCuriosityNotificationMessage(input: {
  hook: CuriosityHook;
  evidence: CuriosityEvidenceGateResult;
}): CuriosityNotificationMessage | null {
  const excerpt = input.evidence.excerpt?.trim();
  if (!excerpt) return null;

  const quotedExcerpt = excerpt.includes('"') ? excerpt : `"${excerpt}"`;

  let body: string;
  if (input.evidence.reason === "unsurfaced_contradiction") {
    body = `Your notes pull in two directions around ${quotedExcerpt}. What changed between those moments?`;
  } else if (input.evidence.themeLabel) {
    body = `You keep returning to "${input.evidence.themeLabel}" — latest line: ${quotedExcerpt}. What is that thread trying to say now?`;
  } else {
    body = `This line keeps showing up in your archive: ${quotedExcerpt}. What do you notice about it today?`;
  }

  if (isGenericCuriosityPrompt(body)) return null;

  return {
    title: TITLE,
    body,
    citedEntryIds: input.evidence.citedEntryIds,
    hookId: input.hook.id,
  };
}
