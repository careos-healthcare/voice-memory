"use client";

import { useEffect } from "react";

import { InstallPrompt } from "@/components/mobile/InstallPrompt";

/** Registers offline shell SW and optional quiet install affordance. */
export function PwaBootstrap() {
  useEffect(() => {
    if (typeof window === "undefined" || !("serviceWorker" in navigator)) return;
    navigator.serviceWorker.register("/sw.js").catch(() => {
      /* quiet — PWA still works without SW */
    });
  }, []);

  return <InstallPrompt />;
}
