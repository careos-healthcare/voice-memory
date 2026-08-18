"use client";

import { useEffect, useState } from "react";

import { pickSilenceIntelligenceUserLine } from "@/lib/restraint/silence-intelligence";

export function QuietSilenceLine() {
  const [line, setLine] = useState<string | null>(null);

  useEffect(() => {
    setLine(pickSilenceIntelligenceUserLine());
  }, []);

  if (!line) return null;

  return <p className="text-sm leading-relaxed text-zinc-500/90">{line}</p>;
}
