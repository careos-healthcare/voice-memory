"use client";

import { useCallback, useEffect, useState } from "react";

import { getQuietLimits, isQuietModeEnabled, setQuietModeEnabled } from "@/lib/quiet-mode";

export function useQuietMode() {
  const [quiet, setQuiet] = useState(false);

  useEffect(() => {
    setQuiet(isQuietModeEnabled());
    const handler = () => setQuiet(isQuietModeEnabled());
    window.addEventListener("voicememory:quiet-mode", handler);
    return () => window.removeEventListener("voicememory:quiet-mode", handler);
  }, []);

  const toggle = useCallback((enabled: boolean) => {
    setQuietModeEnabled(enabled);
    setQuiet(enabled);
  }, []);

  return { quiet, toggle, limits: getQuietLimits(quiet) };
}
