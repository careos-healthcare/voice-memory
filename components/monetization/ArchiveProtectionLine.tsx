"use client";

import { useEffect, useState } from "react";

import { pickArchiveProtectionText } from "@/lib/monetization/pick-archive-protection";
import type { PremiumSurface } from "@/types/monetization-validation";

export function ArchiveProtectionLine({ surface }: { surface: PremiumSurface }) {
  const [line, setLine] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void pickArchiveProtectionText(surface).then((text) => {
      if (active) setLine(text);
    });
    return () => {
      active = false;
    };
  }, [surface]);

  if (!line) return null;

  return (
    <p className="text-sm font-normal leading-[1.75] text-zinc-500/90">{line}</p>
  );
}
