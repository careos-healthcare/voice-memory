"use client";

import { useEffect } from "react";

import { registerCapacitorDeepLinks } from "@/lib/mobile/capacitor-bootstrap";
import { isNativeWrapper } from "@/lib/mobile/platform";

/** Capacitor-only: deep links and native runtime hooks. No push, no fake native features. */
export function NativeBootstrap() {
  useEffect(() => {
    if (!isNativeWrapper()) return;
    let cleanup: (() => void) | undefined;
    void registerCapacitorDeepLinks().then((dispose) => {
      cleanup = dispose;
    });
    return () => cleanup?.();
  }, []);

  return null;
}
