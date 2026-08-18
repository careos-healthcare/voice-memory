"use client";

import { VisualToneProvider } from "@/components/providers/VisualToneProvider";

/** Marketing-site providers — no mobile capture, storage, or retention engines. */
export function AppProviders({ children }: { children: React.ReactNode }) {
  return <VisualToneProvider>{children}</VisualToneProvider>;
}
