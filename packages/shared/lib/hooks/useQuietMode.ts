"use client";

import { useCallback, useEffect, useState } from "react";

import { getQuietLimits, isFullDetailEnabled, setFullDetailEnabled } from "@/lib/quiet-mode";

export function useQuietMode() {
  const [quiet, setQuiet] = useState(true);

  useEffect(() => {
    setQuiet(!isFullDetailEnabled());
    const handler = () => setQuiet(!isFullDetailEnabled());
    window.addEventListener("voicememory:quiet-mode", handler);
    return () => window.removeEventListener("voicememory:quiet-mode", handler);
  }, []);

  const toggleFullDetail = useCallback((enabled: boolean) => {
    setFullDetailEnabled(enabled);
    setQuiet(!enabled);
  }, []);

  return { quiet, fullDetail: !quiet, toggleFullDetail, limits: getQuietLimits(quiet) };
}
