"use client";

import { useEffect } from "react";

import {
  applyVisualToneToDocument,
  resolveActiveVisualTone,
} from "@/lib/personalization/visual-tone";

/** Applies calm visual tone to the document — no flash, no bright themes. */
export function VisualToneProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    const apply = () => applyVisualToneToDocument(resolveActiveVisualTone());
    apply();

    window.addEventListener("voicememory:visual-tone", apply);
    const interval = window.setInterval(apply, 60_000);

    return () => {
      window.removeEventListener("voicememory:visual-tone", apply);
      window.clearInterval(interval);
    };
  }, []);

  return children;
}
