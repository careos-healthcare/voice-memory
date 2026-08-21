"use client";

import { useEffect, useState } from "react";

import { useAuthPrompt } from "@/archived-components/_archived/auth/AuthPromptProvider";
import {
  buildHomepageCarryoverLine,
  type HomepageCarryover,
} from "@/lib/sync/cross-device-continuity";

export function CrossDeviceCarryoverLine() {
  const { requestAuth } = useAuthPrompt();
  const [carryover, setCarryover] = useState<HomepageCarryover | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setCarryover(buildHomepageCarryoverLine({ requirePending: true }));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  if (!carryover) return null;

  const content = (
    <p className="text-sm font-normal leading-[1.75] text-zinc-400">{carryover.line}</p>
  );

  if (carryover.href) {
    return (
      <button
        type="button"
        onClick={() => {
          if (!requestAuth("cross_device")) {
            window.location.href = carryover.href!;
          }
        }}
        className="block w-full rounded-xl border border-white/[0.06] bg-white/[0.02] px-4 py-3 text-left transition-colors hover:bg-white/[0.04]"
      >
        {content}
      </button>
    );
  }

  return (
    <div className="rounded-xl border border-white/[0.06] bg-white/[0.02] px-4 py-3">
      {content}
    </div>
  );
}
