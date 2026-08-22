import { assertWriteAllowed } from "@/lib/runtime/render-safe";
import type { ThoughtPattern } from "@/types/clarity";

const PATTERNS_KEY = "voicememory_thought_patterns";
const DISMISS_PREFIX = "voicememory_clarity_dismiss:";

type PatternStore = Record<string, ThoughtPattern[]>;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readStore(): PatternStore {
  if (!isBrowser()) return {};
  try {
    const raw = localStorage.getItem(PATTERNS_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as PatternStore;
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

function writeStore(store: PatternStore): void {
  if (!isBrowser()) return;
  assertWriteAllowed("clarity-storage:writeStore");
  localStorage.setItem(PATTERNS_KEY, JSON.stringify(store));
}

export function readThoughtPatternsForEntryFromStore(entryId: string): ThoughtPattern[] {
  const rows = readStore()[entryId];
  return Array.isArray(rows) ? rows : [];
}

export function persistThoughtPatternsForEntryInStore(
  entryId: string,
  patterns: ThoughtPattern[],
): void {
  assertWriteAllowed("clarity-storage:persistThoughtPatterns");
  const store = readStore();
  store[entryId] = patterns.slice(0, 6);
  writeStore(store);
}

export function isClarityPromptDismissedInStore(entryId: string): boolean {
  if (!isBrowser()) return false;
  return localStorage.getItem(`${DISMISS_PREFIX}${entryId}`) === "1";
}

export function dismissClarityPromptInStore(entryId: string): void {
  if (!isBrowser()) return;
  assertWriteAllowed("clarity-storage:dismissClarityPrompt");
  localStorage.setItem(`${DISMISS_PREFIX}${entryId}`, "1");
}

export function clearClarityStorageForTests(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(PATTERNS_KEY);
}
