"use client";

import { useEffect } from "react";

import {
  applyAmbientAdaptationToDocument,
  isFirstSessionOfDay,
  markSessionDay,
  prefersReducedMotion,
  resolveAmbientAdaptation,
} from "@/lib/personalization/ambient-adaptation";
import {
  applyVisualToneToDocument,
  resolveActiveVisualTone,
} from "@/lib/personalization/visual-tone";

/** Applies calm visual tone and ambient adaptation — no flash, no bright themes. */
export function VisualToneProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    if (isFirstSessionOfDay()) {
      markSessionDay();
    }

    const apply = () => {
      const baseTone = resolveActiveVisualTone();
      const ambient = resolveAmbientAdaptation(baseTone);
      applyVisualToneToDocument(ambient.resolvedTone);
      applyAmbientAdaptationToDocument(ambient);
    };

    apply();

    window.addEventListener("voicememory:visual-tone", apply);
    window.addEventListener("voicememory:ambient-adaptation", apply);

    const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    const onMotionChange = () => apply();
    motionQuery.addEventListener("change", onMotionChange);

    const interval = prefersReducedMotion() ? null : window.setInterval(apply, 60_000);

    return () => {
      window.removeEventListener("voicememory:visual-tone", apply);
      window.removeEventListener("voicememory:ambient-adaptation", apply);
      motionQuery.removeEventListener("change", onMotionChange);
      if (interval !== null) window.clearInterval(interval);
    };
  }, []);

  return children;
}
