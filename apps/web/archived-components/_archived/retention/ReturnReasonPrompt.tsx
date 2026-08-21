"use client";

import { useState } from "react";
import { X } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import {
  RETURN_REASON_LABELS,
  RETURN_REASON_OPTIONS,
  markReturnReasonAskedThisSession,
  saveReturnReason,
} from "@/lib/retention/return-reason-survey";
import type { ReturnReason } from "@/types/retention-discovery";

interface ReturnReasonPromptProps {
  sessionNumber: number;
  onDone: () => void;
}

export function ReturnReasonPrompt({ sessionNumber, onDone }: ReturnReasonPromptProps) {
  const [otherText, setOtherText] = useState("");
  const [pending, setPending] = useState<ReturnReason | null>(null);

  const dismiss = () => {
    markReturnReasonAskedThisSession(sessionNumber);
    onDone();
  };

  const submit = (reason: ReturnReason) => {
    if (reason === "other" && !otherText.trim()) {
      setPending("other");
      return;
    }
    saveReturnReason({
      reason,
      otherText: reason === "other" ? otherText : undefined,
      sessionNumber,
    });
    markReturnReasonAskedThisSession(sessionNumber);
    onDone();
  };

  return (
    <div
      className="fixed inset-x-0 bottom-0 z-50 border-t border-white/10 bg-zinc-950/95 px-4 py-4 pb-[max(1rem,env(safe-area-inset-bottom))] backdrop-blur sm:px-6"
      role="dialog"
      aria-labelledby="return-reason-title"
    >
      <div className="mx-auto max-w-lg">
        <div className="flex items-start justify-between gap-3">
          <p id="return-reason-title" className="text-sm font-medium text-zinc-200">
            What brought you back today?
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
        <ul className="mt-3 max-h-[40vh] space-y-1 overflow-y-auto">
          {RETURN_REASON_OPTIONS.map((reason) => (
            <li key={reason}>
              <button
                type="button"
                className="w-full rounded-lg px-3 py-2 text-left text-sm text-zinc-400 hover:bg-white/5 hover:text-zinc-200"
                onClick={() => submit(reason)}
              >
                {RETURN_REASON_LABELS[reason]}
              </button>
            </li>
          ))}
        </ul>
        {pending === "other" ? (
          <div className="mt-3 space-y-2">
            <input
              type="text"
              value={otherText}
              onChange={(e) => setOtherText(e.target.value)}
              placeholder="Brief note (optional)"
              className="w-full rounded-lg border border-white/10 bg-black/30 px-3 py-2 text-sm text-zinc-200 placeholder:text-zinc-600"
            />
            <Button type="button" size="sm" variant="secondary" onClick={() => submit("other")}>
              Save
            </Button>
          </div>
        ) : null}
      </div>
    </div>
  );
}
