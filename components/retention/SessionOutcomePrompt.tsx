"use client";

import { X } from "lucide-react";

import {
  SESSION_OUTCOME_LABELS,
  SESSION_OUTCOME_OPTIONS,
  markSessionOutcomeAsked,
  saveSessionOutcome,
} from "@/lib/retention/session-outcome";
import type { SessionOutcome } from "@/types/retention-discovery";

interface SessionOutcomePromptProps {
  sessionNumber: number;
  onDone: () => void;
}

export function SessionOutcomePrompt({ sessionNumber, onDone }: SessionOutcomePromptProps) {
  const dismiss = () => {
    markSessionOutcomeAsked(sessionNumber);
    onDone();
  };

  const submit = (outcome: SessionOutcome) => {
    saveSessionOutcome({ outcome, sessionNumber });
    markSessionOutcomeAsked(sessionNumber);
    onDone();
  };

  return (
    <div
      className="fixed inset-x-0 bottom-0 z-50 border-t border-white/10 bg-zinc-950/95 px-4 py-4 pb-[max(1rem,env(safe-area-inset-bottom))] backdrop-blur sm:px-6"
      role="dialog"
      aria-labelledby="session-outcome-title"
    >
      <div className="mx-auto max-w-lg">
        <div className="flex items-start justify-between gap-3">
          <p id="session-outcome-title" className="text-sm font-medium text-zinc-200">
            Did this help?
          </p>
          <button
            type="button"
            aria-label="Dismiss"
            className="shrink-0 rounded-full p-1 text-zinc-600 hover:bg-white/5 hover:text-zinc-400"
            onClick={dismiss}
          >
            <X className="h-4 w-4" />
          </button>
        </div>
        <ul className="mt-3 space-y-1">
          {SESSION_OUTCOME_OPTIONS.map((outcome) => (
            <li key={outcome}>
              <button
                type="button"
                className="w-full rounded-lg px-3 py-2 text-left text-sm text-zinc-400 hover:bg-white/5 hover:text-zinc-200"
                onClick={() => submit(outcome)}
              >
                {SESSION_OUTCOME_LABELS[outcome]}
              </button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
