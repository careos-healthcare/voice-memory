"use client";

import { useCallback, useEffect, useState } from "react";

import {
  isListeningModeEnabled,
  LISTENING_MODE_CHANGE_EVENT,
  setListeningModeEnabled,
} from "@/lib/listening-mode";

export function useListeningMode() {
  const [enabled, setEnabled] = useState(false);

  const refresh = useCallback(() => {
    setEnabled(isListeningModeEnabled());
  }, []);

  useEffect(() => {
    refresh();
    window.addEventListener(LISTENING_MODE_CHANGE_EVENT, refresh);
    return () => window.removeEventListener(LISTENING_MODE_CHANGE_EVENT, refresh);
  }, [refresh]);

  const setListeningMode = useCallback((next: boolean) => {
    setListeningModeEnabled(next);
    setEnabled(next);
  }, []);

  return { listeningMode: enabled, setListeningMode, refresh };
}
