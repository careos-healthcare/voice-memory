"use client";

import { Mic } from "lucide-react";

import { PrivacyNotice } from "@/components/system/PrivacyNotice";
import { StatusBadge } from "@/components/system/StatusBadge";
import { cn } from "@/lib/utils";

export type RecordUiPhase =
  | "ready"
  | "recording"
  | "processing"
  | "complete"
  | "error";

const PHASE_COPY: Record<
  RecordUiPhase,
  { label: string; tone: "neutral" | "warning" | "success" | "error" }
> = {
  ready: { label: "Ready to record", tone: "neutral" },
  recording: { label: "Listening", tone: "warning" },
  processing: { label: "Saving your words", tone: "neutral" },
  complete: { label: "Saved", tone: "success" },
  error: { label: "Needs attention", tone: "error" },
};

export function RecordCaptureChrome({
  phase = "ready",
  className,
  showFirstTimeHint = false,
}: {
  phase?: RecordUiPhase;
  className?: string;
  showFirstTimeHint?: boolean;
}) {
  const meta = PHASE_COPY[phase];

  return (
    <div className={cn("w-full max-w-md space-y-4 px-4", className)}>
      <div
        className="flex flex-wrap items-center justify-center gap-2"
        role="status"
        aria-live="polite"
        aria-atomic="true"
      >
        <Mic className="h-4 w-4 text-violet-300/80" aria-hidden />
        <span className="text-sm text-zinc-300">Voice capture</span>
        <StatusBadge tone={meta.tone}>{meta.label}</StatusBadge>
      </div>
      {showFirstTimeHint ? (
        <p className="text-center text-sm leading-relaxed text-zinc-400">
          Tap the mic when you are ready. One reflection at a time — saved on this device unless you
          sign in to back up.
        </p>
      ) : null}
      <PrivacyNotice showPolicyLink={false} className="justify-center text-center" />
    </div>
  );
}
