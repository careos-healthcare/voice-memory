"use client";

import { useEffect, useState } from "react";

import { pickEmotionalProofLine, type EmotionalProofSurface } from "@/lib/social-proof/proof-surfaces";
import { getMemoryEligibleEntries } from "@/lib/storage";

export function EmotionalProofLine({ surface }: { surface: EmotionalProofSurface }) {
  const [line, setLine] = useState<string | null>(null);

  useEffect(() => {
    setLine(pickEmotionalProofLine(surface, getMemoryEligibleEntries()));
  }, [surface]);

  if (!line) return null;

  return (
    <p className="text-sm leading-relaxed text-zinc-500/90">{line}</p>
  );
}
