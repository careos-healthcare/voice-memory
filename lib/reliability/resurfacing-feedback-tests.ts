import assert from "node:assert/strict";

import { pickFirstReturnMoment } from "@/lib/continuity/first-return-moment";
import {
  isPhraseOnResurfacingCooldown,
  phraseKeyFromQuote,
  recordResurfacingFeedback,
  userFeedbackPenaltyForPhrase,
} from "@/lib/resurfacing/resurfacing-feedback";
import {
  buildResurfacingScores,
  shouldShowResurfacing,
} from "@/lib/resurfacing/resurfacing-scoring";
import type { JournalEntry } from "@/types/journal";

function entry(id: string, transcript: string, day: string): JournalEntry {
  return {
    id,
    createdAt: `${day}T12:00:00.000Z`,
    transcript,
    durationSeconds: 30,
    reflection: {
      mood: "focused",
      emotionalIntensity: 6,
      recurringThemes: ["work"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
      exactLanguagePattern: "waiting for the contractor to call back",
      concreteObservation: "Speaking about the kitchen delay again.",
      repeatedSignal: "waiting for the contractor",
    },
  };
}

export function runResurfacingFeedbackTests(): { failures: string[] } {
  const failures: string[] = [];
  const g = globalThis as typeof globalThis & { localStorage?: Storage | undefined };

  const store = new Map<string, string>();
  const mockStorage: Storage = {
    getItem: (k: string) => store.get(k) ?? null,
    setItem: (k: string, v: string) => store.set(k, v),
    removeItem: (k: string) => store.delete(k),
    clear: () => store.clear(),
    key: () => null,
    get length() {
      return store.size;
    },
  } as Storage;
  g.localStorage = mockStorage;

  try {
    const phrase = "waiting for the contractor to call back about the kitchen";
    const key = phraseKeyFromQuote(phrase);
    assert.ok(key);

    const before = buildResurfacingScores({
      quote: phrase,
      appearances: 3,
      threadType: "repeated_phrase",
    });
    assert.ok(before.finalResurfacingConfidence > 0);

    recordResurfacingFeedback({
      kind: "not_me",
      quote: phrase,
      surface: "first_return",
    });

    assert.ok(userFeedbackPenaltyForPhrase(key) >= 35);
    assert.ok(isPhraseOnResurfacingCooldown(key));

    const after = buildResurfacingScores({
      quote: phrase,
      appearances: 3,
      threadType: "repeated_phrase",
    });
    assert.equal(shouldShowResurfacing(after, phrase), false);

    const entries = [
      entry("1", `Today I said ${phrase} again in my voice.`, "2026-05-20"),
      entry("2", `Yesterday I kept saying ${phrase} about the project.`, "2026-05-18"),
    ];
    const moment = pickFirstReturnMoment(entries);
    if (moment?.quote.toLowerCase().includes("contractor")) {
      failures.push("not_me should suppress same phrase resurfacing");
    }

    const junk = pickFirstReturnMoment([
      entry("a", "thank you for watching", "2026-05-01"),
      entry("b", "thank you for watching again", "2026-05-02"),
    ]);
    if (junk !== null) {
      failures.push("junk transcripts must not produce moment");
    }
  } catch (error) {
    failures.push(error instanceof Error ? error.message : String(error));
  }

  return { failures };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const result = runResurfacingFeedbackTests();
  if (result.failures.length > 0) {
    console.error("resurfacing-feedback-tests failed:\n", result.failures.join("\n"));
    process.exit(1);
  }
  console.log("resurfacing-feedback-tests ok");
}
