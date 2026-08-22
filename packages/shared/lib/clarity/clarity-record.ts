import type { ClarityRecorderPromptKey } from "@/types/clarity";
import { CLARITY_RECORDER_PROMPTS } from "@/lib/clarity/clarity-copy";

export const CLARITY_RECORD_KEY = "voicememory_clarity_record";
export const CLARITY_AFTER_SAVE_KEY = "voicememory_clarity_after_save";

export interface ClarityRecordContext {
  id: string;
  entryId: string;
  sourceEntryId: string;
  recorderPrompt: string;
  promptKey: ClarityRecorderPromptKey;
  anchorSnippet: string;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

const PROMPT_KEYS: ClarityRecorderPromptKey[] = [
  "what_happened",
  "what_assumed",
  "what_avoided",
  "what_unresolved",
  "what_changed",
];

/** One recorder line — never stack prompts. */
export function pickClarityRecorderPrompt(entryId: string): {
  key: ClarityRecorderPromptKey;
  text: string;
} {
  let hash = 0;
  for (let i = 0; i < entryId.length; i += 1) {
    hash = (hash + entryId.charCodeAt(i) * (i + 1)) % 9973;
  }
  const key = PROMPT_KEYS[hash % PROMPT_KEYS.length] ?? "what_happened";
  return { key, text: CLARITY_RECORDER_PROMPTS[key] };
}

export function buildClarityRecordContext(input: {
  entryId: string;
  anchorSnippet: string;
}): ClarityRecordContext {
  const { key, text } = pickClarityRecorderPrompt(input.entryId);
  return {
    id: `clarity-${input.entryId}`,
    entryId: input.entryId,
    sourceEntryId: input.entryId,
    recorderPrompt: text,
    promptKey: key,
    anchorSnippet: input.anchorSnippet.trim().slice(0, 220),
  };
}

export function storeClarityRecordContext(context: ClarityRecordContext): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(CLARITY_RECORD_KEY, JSON.stringify(context));
  sessionStorage.setItem("voicememory_reflection_after_clarity_pending", context.entryId);
}

export function peekClarityRecordContext(): ClarityRecordContext | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(CLARITY_RECORD_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<ClarityRecordContext>;
    if (!parsed.id || !parsed.entryId || !parsed.recorderPrompt) return null;
    return parsed as ClarityRecordContext;
  } catch {
    return null;
  }
}

export function consumeClarityRecordContext(): ClarityRecordContext | null {
  const ctx = peekClarityRecordContext();
  if (!ctx || !isBrowser()) return ctx;
  sessionStorage.removeItem(CLARITY_RECORD_KEY);
  return ctx;
}

export function storeClarityAfterSaveLine(line: string): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(CLARITY_AFTER_SAVE_KEY, line);
}

export function consumeClarityAfterSaveLine(): string | null {
  if (!isBrowser()) return null;
  const line = sessionStorage.getItem(CLARITY_AFTER_SAVE_KEY);
  if (line) sessionStorage.removeItem(CLARITY_AFTER_SAVE_KEY);
  sessionStorage.removeItem("voicememory_reflection_after_clarity_pending");
  return line;
}

export function peekReflectionAfterClarityPending(): string | null {
  if (!isBrowser()) return null;
  return sessionStorage.getItem("voicememory_reflection_after_clarity_pending");
}
